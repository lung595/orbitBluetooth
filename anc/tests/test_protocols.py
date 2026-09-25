"""Each brand against a scripted headset: what it sends at start, how it
reads the headset's answers and notifications, what a mode change sends.
Replies are built from the documented formats."""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from protocols import FAMILIES, huawei, nothing, oppo, soundcore, xiaomi, sony  # noqa: E402
from protocols import earfun, moondrop, safer  # noqa: E402
from protocols.checksums import sum8  # noqa: E402


def h(text):
    return bytes.fromhex(text.replace(" ", ""))


def make(family, name=""):
    sent = []
    proto = FAMILIES[family](sent.append, name)
    proto.start()
    return proto, sent


class Sony(unittest.TestCase):
    def test_xm6_query_reply_leaves_mode_unknown(self):
        # P16: the XM6 answers a query with on/off = 0 even when cancelling
        proto = FAMILIES["sony"](lambda d: None, "WH-1000XM6")
        proto.version = 2
        proto._data(h("67 19 01 00 00 00 14 00 00"))
        self.assertIsNone(proto.state["mode"])
        proto._data(h("67 19 01 00 01 00 14 00 00"))
        self.assertEqual(proto.state["mode"], "ambient")
        proto._data(h("69 19 01 01 00 00 14 00 00"))   # notifications are exact
        self.assertEqual(proto.state["mode"], "nc")

    def test_xm6_charging_flag_is_a_bit(self):
        # Real WH-1000XM6 replies: 23 00 50 00 on battery, 23 00 4f 03 charging
        proto = FAMILIES["sony"](lambda d: None, "WH-1000XM6")
        proto.version = 2
        proto._data(h("23 00 50 00"))
        self.assertEqual(proto.state["battery"]["single"], {"level": 80, "charging": False})
        proto._data(h("23 00 4f 03"))
        self.assertEqual(proto.state["battery"]["single"], {"level": 79, "charging": True})

    def test_frames_ack_every_data_frame(self):
        sent = []
        proto = FAMILIES["sony"](sent.append)
        proto.receive(sony.encode(0x0C, 0, h("69 19 01 01 01 00 0f 00 00")))
        self.assertIn(h("3e 01 01 00 00 00 00 02 3c"), sent)
        self.assertEqual(proto.state["mode"], "ambient")


class Nothing(unittest.TestCase):
    def test_start_mode_battery_and_set(self):
        proto, sent = make("nothing", "Nothing Ear (2)")
        self.assertEqual([f[3:5] for f in sent], [h("07 c0"), h("1e c0")])   # battery, then mode
        proto.receive(nothing.encode(0x401E, h("01 07 00"), 0))
        self.assertTrue(proto.ready)
        self.assertEqual(proto.state["mode"], "ambient")
        proto.receive(nothing.encode(0xE001, h("03 02 50 03 d5 04 40"), 1))
        self.assertEqual(proto.state["battery"]["right"], {"level": 85, "charging": True})
        self.assertEqual(proto.state["battery"]["case"]["level"], 64)
        sent.clear()
        proto.set_mode("off")
        self.assertEqual(sent[0][3:5], h("0f f0"))
        self.assertEqual(sent[0][8:11], h("01 05 00"))

    def test_models_without_anc(self):
        proto, _ = make("nothing", "Nothing Ear (stick)")
        self.assertEqual(proto.features["modes"], [])

    def test_adaptive_models(self):
        proto, _ = make("nothing", "Nothing Ear (a)")
        self.assertIn("adaptive", proto.features["modes"])


class Samsung(unittest.TestCase):
    def test_extended_status_and_notifications(self):
        proto, sent = make("samsung", "Galaxy Buds2 Pro")
        self.assertEqual(sent, [])            # the buds speak first
        status = bytearray(28)
        status[2], status[3], status[7] = 70, 65, 40
        status[12], status[23], status[26] = 1, 2, 1
        proto.receive(proto.encode(0x61, bytes(status)))
        self.assertTrue(proto.ready)
        self.assertEqual(proto.state["mode"], "nc")
        self.assertEqual(proto.state["ambient"], 2)
        self.assertTrue(proto.state["chat"])
        self.assertEqual(proto.state["battery"]["case"]["level"], 40)
        self.assertEqual(sent[0][3], 0x88)    # manager info after the first status
        proto.receive(proto.encode(0x77, h("02")))
        self.assertEqual(proto.state["mode"], "ambient")

    def test_buds_live_uses_the_anc_switch(self):
        proto, sent = make("samsung", "Galaxy Buds Live (8A2C)")
        self.assertEqual(proto.features["modes"], ["nc", "off"])
        proto.set_mode("nc")
        self.assertEqual(sent[-1][3:5], h("98 01"))


class Bose(unittest.TestCase):
    def test_qc35_anr(self):
        proto, sent = make("bose", "Bose QC35 II")
        self.assertEqual(sent[0], h("00 01 01 00"))    # BMAP version first
        proto.receive(h("01 06 03 02 03 0b"))            # low cancelling
        self.assertEqual(proto.state["mode"], "nc")
        proto.receive(h("02 02 03 01 55"))
        self.assertEqual(proto.state["battery"]["single"]["level"], 85)
        proto.set_mode("off")
        self.assertEqual(sent[-1], h("01 06 00 01 00"))

    def test_audio_modes_family(self):
        proto, sent = make("bose", "Bose QC Ultra Headphones")
        proto.receive(h("1f 03 03 01 01"))
        self.assertEqual(proto.state["mode"], "ambient")
        proto.set_mode("nc")
        self.assertEqual(sent[-1], h("1f 03 05 02 00 00"))

    def test_error_means_no_noise_control(self):
        proto, _ = make("bose", "Bose SoundLink Flex")
        proto.receive(h("1f 03 04 01 04"))
        self.assertTrue(proto.ready)
        self.assertEqual(proto.features["modes"], [])


def soundcore_reply(command, body):
    raw = h("09 ff 00 00 01") + command + (10 + len(body)).to_bytes(2, "little") + body
    return raw + bytes([sum8(raw)])


class Soundcore(unittest.TestCase):
    def test_life_q30_state_and_notification(self):
        proto, sent = make("soundcore", "Soundcore Life Q30")
        self.assertEqual(sent[0], soundcore.encode(h("01 01")))
        body = bytearray(60)
        body[0], body[1] = 4, 0
        body[35:39] = h("01 01 00 00")           # transparency
        proto.receive(soundcore_reply(h("01 01"), bytes(body)))
        self.assertEqual(proto.state["mode"], "ambient")
        self.assertEqual(proto.state["battery"]["single"]["level"], 80)
        proto.receive(soundcore_reply(h("06 01"), h("00 02 01 00")))
        self.assertEqual(proto.state["mode"], "nc")
        proto.set_mode("off")
        self.assertEqual(sent[-1], soundcore.encode(h("06 81"), h("02 02 01 00")))

    def test_space_q45_adaptive(self):
        proto, sent = make("soundcore", "Soundcore Space Q45")
        self.assertIn("adaptive", proto.features["modes"])
        proto.receive(soundcore_reply(h("06 01"), h("00 51 01 01 00 03")))
        self.assertEqual(proto.state["mode"], "adaptive")


class Huawei(unittest.TestCase):
    def test_read_and_set(self):
        proto, sent = make("huawei", "HUAWEI FreeBuds Pro 3")
        self.assertIn("adaptive", proto.features["modes"])
        self.assertTrue(proto.features["voice"])
        proto.receive(huawei.encode(h("2b 2a"), [(1, h("03 01"))]))    # dynamic cancelling
        self.assertEqual(proto.state["mode"], "adaptive")
        proto.receive(huawei.encode(h("01 08"), [(1, h("50")), (2, h("50 4b 1e")), (3, h("00 01 00"))]))
        self.assertEqual(proto.state["battery"]["right"], {"level": 75, "charging": True})
        sent.clear()
        proto.set_mode("ambient")
        self.assertEqual(huawei.parse_params(sent[0][6:-2])[1], h("02 ff"))

    def test_nc_asks_for_the_normal_level(self):
        # Real FreeBuds Pro: off (00 00), then "nc" came back as dynamic (03 01)
        proto, sent = make("huawei", "HUAWEI FreeBuds Pro")
        proto.receive(huawei.encode(h("2b 2a"), [(1, h("00 00"))]))
        sent.clear()
        proto.set_mode("nc")
        values = [huawei.parse_params(f[6:-2]).get(1) for f in sent if f[4:6] == h("2b 04")]
        self.assertEqual(values, [h("01 ff"), h("01 00")])

    def test_charging_per_part(self):
        proto, _ = make("huawei", "HUAWEI FreeBuds Pro 3")
        proto.receive(huawei.encode(h("01 27"), [(2, h("50 4b 1e")), (3, h("00 00 01"))]))
        self.assertFalse(proto.state["battery"]["left"]["charging"])
        self.assertTrue(proto.state["battery"]["case"]["charging"])

    def test_crc_checked(self):
        proto, _ = make("huawei", "HUAWEI FreeBuds 5i")
        bad = bytearray(huawei.encode(h("2b 2a"), [(1, h("00 02"))]))
        bad[-1] ^= 0xFF
        proto.receive(bytes(bad))
        self.assertIsNone(proto.state["mode"])

    def test_models_without_anc(self):
        proto, _ = make("huawei", "HUAWEI FreeBuds SE")
        self.assertEqual(proto.features["modes"], [])


def oppo_reply(command, payload):
    body = h("00 00") + command.to_bytes(2, "little") + b"\x00" + len(payload).to_bytes(2, "little") + payload
    return bytes([0xAA, len(body)]) + body


class Oppo(unittest.TestCase):
    def test_probe_then_mode(self):
        proto, sent = make("oppo", "realme Buds Air6 Pro")
        self.assertEqual(sent[0][4:6], h("0c 01"))
        proto.receive(oppo_reply(0x810C, h("00 01 01 08")))
        self.assertEqual(proto.state["mode"], "nc")
        self.assertEqual(proto.features["modes"], ["nc", "ambient", "off"])
        proto.receive(oppo_reply(0x8106, h("00 03 01 50 02 d0 03 00")))
        self.assertEqual(proto.state["battery"]["right"], {"level": 80, "charging": True})
        self.assertNotIn("case", proto.state["battery"])   # 0% case = lid closed

    def test_silent_model_shows_battery_only(self):
        proto, _ = make("oppo", "OPPO Enco Air")
        proto.tick(0)
        proto.tick(10)
        self.assertTrue(proto.ready)
        self.assertEqual(proto.features["modes"], [])


class Xiaomi(unittest.TestCase):
    def test_login_then_state(self):
        proto, sent = make("xiaomi", "Redmi Buds 5 Pro")
        self.assertEqual(sent[0][3:5], h("c4 50"))
        # The buds answer our challenge, then send theirs
        proto.receive(xiaomi.encode(0x04, 0x50, 0, h("01") + bytes(16)))
        self.assertEqual(sent[-1][3:5], h("c4 51"))
        challenge = bytes(range(16))
        proto.receive(xiaomi.encode(0xC0, 0x50, 9, h("01") + challenge))
        self.assertEqual(sent[-1][3:5], h("04 50"))
        # answer = 01 + SAFER+ response (after type, opcode, length, status, seq)
        self.assertEqual(sent[-1][9], 0x01)
        self.assertEqual(sent[-1][10:26], safer.respond(challenge))
        proto.receive(xiaomi.encode(0xC0, 0x51, 10, h("01")))
        self.assertEqual([s[4] for s in sent[-2:]], [0x02, 0x09])     # info, run info
        proto.receive(xiaomi.encode(0x04, 0x09, 3, h("02 09 01")))
        self.assertEqual(proto.state["mode"], "nc")
        proto.receive(xiaomi.encode(0xC0, 0x0E, 11, h("04 00 5a d0 ff 02 04 02")))
        self.assertEqual(proto.state["mode"], "ambient")
        self.assertEqual(proto.state["battery"]["right"], {"level": 80, "charging": True})
        self.assertNotIn("case", proto.state["battery"])
        self.assertEqual(sent[-1][3:5], h("04 0e"))   # status acknowledged


class SmallBrands(unittest.TestCase):
    def test_earfun(self):
        proto, sent = make("earfun", "EarFun Air Pro 4")
        reply = lambda cmd, value: earfun.encode(cmd | 0x8000, bytes([0, value]))  # noqa: E731
        proto.receive(reply(0x0315, 1))
        proto.receive(reply(0x033B, 4))
        self.assertEqual(proto.state["mode"], "adaptive")
        proto.receive(reply(0x0306, 70))
        self.assertEqual(proto.state["battery"]["left"]["level"], 70)
        proto.set_mode("ambient")
        self.assertEqual(sent[-1], earfun.encode(0x0314, b"\x02"))

    def test_moondrop(self):
        proto, sent = make("moondrop", "Space Travel 2")
        self.assertEqual(sent[0], h("ff 04 00 00 00 1d 10 03"))
        response = (0x08 << 9) | (2 << 7) | 0x03
        proto.receive(h("ff 04 00 01 00 1d") + response.to_bytes(2, "big") + h("02"))
        self.assertEqual(proto.state["mode"], "ambient")
        proto.set_mode("nc")
        self.assertEqual(sent[-1], h("ff 04 00 01 00 1d 10 04 02"))

    def test_haylou(self):
        proto, sent = make("haylou", "HAYLOU S35 ANC")
        proto.receive(h("aa bb cc c0 00 00 04 00 00 00 3c dd ee ff"))
        self.assertTrue(proto.ready)
        self.assertEqual(proto.state["battery"]["single"]["level"], 60)
        self.assertIsNone(proto.state["mode"])
        proto.set_mode("nc")
        self.assertEqual(sent[-1], h("aa bb cc c0 08 00 04 00 02 04 01 dd ee ff"))

    def test_onemore(self):
        proto, sent = make("onemore", "1MORE SonoFlow")
        proto.receive(h("01 01 00 5f 00 01 00 00 00 03"))
        self.assertEqual(proto.state["mode"], "ambient")
        proto.set_mode("off")
        self.assertEqual(sent[-1], h("11 01 00 5e 00 01 00 13 5c 00"))


if __name__ == "__main__":
    unittest.main()
