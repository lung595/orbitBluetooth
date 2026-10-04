"""Sony wearing detection (table 2) and conversation length, against a
scripted headset. The bytes are the layouts documented by
mos9527/SonyHeadphonesClient; none of this has met a real headset yet."""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from protocols import FAMILIES  # noqa: E402
from protocols.sony_frame import T_ACK, T_DATA, T_DATA2, decode, encode  # noqa: E402

PROTOCOL_INFO = "01 00 00 00 02 00 00 {t2}"
FUNCTIONS = "07 00 {n:02x} {codes}"


def h(text):
    return bytes.fromhex(text.replace(" ", ""))


class Headset:
    """Plays the headset: acknowledges what the helper sends, answers on request."""

    def __init__(self, table2=True, codes=(0x6D, 0xFC, 0xF1)):
        self.sent = []
        self.proto = FAMILIES["sony"](self.sent.append, "WH-1000XM6")
        self.seq = 0
        self.proto.start()
        self.drain()
        self.reply(T_DATA, PROTOCOL_INFO.format(t2="00" if table2 else "01"))
        pairs = " ".join("%02x 00" % c for c in codes)
        self.reply(T_DATA, FUNCTIONS.format(n=len(codes), codes=pairs))
        self.drain()

    def drain(self):
        # Acknowledge until nothing is in flight: every queued packet goes out
        while self.proto.inflight is not None:
            self.proto.receive(encode(T_ACK, 1 - self.proto.seq, b""))

    def reply(self, table, payload):
        self.seq = 1 - self.seq
        self.proto.receive(encode(table, self.seq, h(payload)))

    def packets(self):
        """(table, payload hex) of every data frame the helper sent, in order."""
        frames = [decode(f[1:-1]) for f in self.sent]
        return [(t, p.hex(" ")) for t, _s, p in frames if t != T_ACK]


class Wear(unittest.TestCase):
    def test_table2_frame_layout(self):
        self.assertEqual(encode(T_DATA2, 1, h("f2 00")), h("3e 0e 01 00 00 00 02 f2 00 03 3c"))

    def test_capability_needs_table2_and_a_wearing_function(self):
        self.assertTrue(Headset().proto.features["wear"])
        self.assertTrue(Headset(codes=(0x6D, 0xF6)).proto.features["wear"])
        self.assertFalse(Headset(table2=False).proto.features["wear"])
        self.assertFalse(Headset(codes=(0x6D, 0xFC)).proto.features["wear"])

    def test_nothing_is_sent_until_asked(self):
        headset = Headset()
        self.assertNotIn((T_DATA2, "f2 00"), headset.packets())
        self.assertIsNone(headset.proto.state["wearing"])

    def test_enabling_sends_the_documented_sequence(self):
        headset = Headset()
        headset.proto.set("wear", "on")
        headset.drain()
        self.assertEqual(headset.packets()[-3:], [(T_DATA, "c4 01 00"), (T_DATA2, "06 00"), (T_DATA2, "f2 00")])

    def test_unsupported_headset_ignores_the_request(self):
        headset = Headset(table2=False)
        count = len(headset.packets())
        headset.proto.set("wear", "on")
        headset.drain()
        self.assertEqual(len(headset.packets()), count)

    def test_reply_and_notification_set_the_status(self):
        headset = Headset()
        headset.proto.set("wear", "on")
        headset.drain()
        headset.reply(T_DATA2, "f3 00 00")
        self.assertEqual(headset.proto.state["wearing"], 0)
        headset.reply(T_DATA2, "f5 00 04")
        self.assertEqual(headset.proto.state["wearing"], 4)
        self.assertIn(h("3e 01 %02x 00 00 00 00 %02x 3c" % (1 - headset.seq, 1 - headset.seq + 1)), headset.sent)

    def test_unknown_status_or_other_type_is_ignored(self):
        headset = Headset()
        headset.proto.set("wear", "on")
        headset.drain()
        headset.reply(T_DATA2, "f3 00 00")
        headset.reply(T_DATA2, "f3 00 09")
        headset.reply(T_DATA2, "f3 01 04")
        headset.reply(T_DATA2, "f3 00")
        self.assertEqual(headset.proto.state["wearing"], 0)

    def test_status_is_ignored_while_not_asked(self):
        headset = Headset()
        headset.reply(T_DATA2, "f5 00 04")
        self.assertIsNone(headset.proto.state["wearing"])

    def test_sensor_log_entries_ask_for_the_status_again(self):
        headset = Headset()
        headset.proto.set("wear", "on")
        headset.drain()
        before = headset.packets().count((T_DATA2, "f2 00"))
        for key in (b"unitRemove", b"unitWear"):
            headset.reply(T_DATA, "c9 01 %02x %s" % (len(key), key.hex()))
            headset.drain()
        self.assertEqual(headset.packets().count((T_DATA2, "f2 00")), before + 2)

    def test_other_log_entries_and_malformed_ones_do_nothing(self):
        headset = Headset()
        headset.proto.set("wear", "on")
        headset.drain()
        before = len(headset.packets())
        remove = b"unitRemove".hex()
        for payload in ("c9 01 04 74 61 70 73", "c9 01", "c9 01 40 756e69745265", "c9 00 0a " + remove, "c9 01 00"):
            headset.reply(T_DATA, payload)
            headset.drain()
        self.assertEqual(len(headset.packets()), before)

    def test_a_burst_of_log_entries_queues_one_request(self):
        headset = Headset()
        headset.proto.set("wear", "on")
        headset.drain()
        before = headset.packets().count((T_DATA2, "f2 00"))
        key = b"unitWear".hex()
        # Frames arrive faster than the headset acknowledges: nothing piles up
        for _ in range(5):
            headset.reply(T_DATA, "c9 01 08 " + key)
        headset.drain()
        self.assertEqual(headset.packets().count((T_DATA2, "f2 00")), before + 2)

    def test_log_entries_are_ignored_when_wear_is_off(self):
        headset = Headset()
        before = len(headset.packets())
        headset.reply(T_DATA, "c9 01 08 " + b"unitWear".hex())
        headset.drain()
        self.assertEqual(len(headset.packets()), before)

    def test_disabling_forgets_the_status(self):
        headset = Headset()
        headset.proto.set("wear", "on")
        headset.drain()
        headset.reply(T_DATA2, "f3 00 04")
        headset.proto.set("wear", "off")
        self.assertIsNone(headset.proto.state["wearing"])
        count = len(headset.packets())
        headset.reply(T_DATA, "c9 01 0a " + b"unitRemove".hex())
        headset.drain()
        self.assertEqual(len(headset.packets()), count)

    def test_switching_back_on_does_not_repeat_the_log_request(self):
        headset = Headset()
        for value in ("on", "off", "on"):
            headset.proto.set("wear", value)
            headset.drain()
        self.assertEqual(headset.packets().count((T_DATA, "c4 01 00")), 1)

    def test_retry_keeps_the_table(self):
        # A table 2 request nobody acknowledged is sent again as table 2
        headset = Headset()
        headset.proto.set("wear", "on")
        headset.proto.receive(encode(T_ACK, 1 - headset.proto.seq, b""))   # log acknowledged
        headset.proto.tick(10.0)
        headset.proto.tick(12.0)
        self.assertEqual(headset.sent[-1][1], T_DATA2)


class ConversationEnds(unittest.TestCase):
    def test_read_is_asked_with_the_chat_function(self):
        self.assertIn((T_DATA, "fa 0c"), Headset().packets())
        self.assertNotIn((T_DATA, "fa 0c"), Headset(codes=(0x6D,)).packets())

    def test_hidden_until_the_headset_answers(self):
        headset = Headset()
        self.assertFalse(headset.proto.features["chatEnds"])
        count = len(headset.packets())
        headset.proto.set("chatEnds", "2")
        headset.drain()
        self.assertEqual(len(headset.packets()), count)
        headset.reply(T_DATA, "fb 0c 00 01")
        self.assertTrue(headset.proto.features["chatEnds"])
        self.assertEqual(headset.proto.state["chatEnds"], 1)

    def test_write_sends_back_the_sensitivity_that_was_read(self):
        headset = Headset()
        headset.reply(T_DATA, "fb 0c 01 01")
        headset.proto.set("chatEnds", "3")
        headset.drain()
        self.assertEqual(headset.packets()[-1], (T_DATA, "fc 0c 01 03"))
        self.assertEqual(headset.proto.state["chatEnds"], 3)

    def test_notification_follows_the_buttons(self):
        headset = Headset()
        headset.reply(T_DATA, "fb 0c 00 01")
        headset.reply(T_DATA, "fd 0c 02 00")
        self.assertEqual(headset.proto.state["chatEnds"], 0)
        headset.proto.set("chatEnds", "1")
        headset.drain()
        self.assertEqual(headset.packets()[-1], (T_DATA, "fc 0c 02 01"))

    def test_bad_values_never_reach_the_headset(self):
        headset = Headset()
        headset.reply(T_DATA, "fb 0c 00 01")
        count = len(headset.packets())
        for value in ("4", "-1", "abc", "", "1 2", "٣"):
            headset.proto.set("chatEnds", value)
        headset.drain()
        self.assertEqual(len(headset.packets()), count)

    def test_bad_reports_are_ignored(self):
        headset = Headset()
        for payload in ("fb 0c 00 07", "fb 0c 05 01", "fb 0b 00 01", "fb 0c 00"):
            headset.reply(T_DATA, payload)
        self.assertFalse(headset.proto.features["chatEnds"])
        self.assertIsNone(headset.proto.state["chatEnds"])


if __name__ == "__main__":
    unittest.main()
