"""A buggy or hostile headset: frames and SDP replies no parser expected must
end in "no answer" or a clean error, never a traceback (audit 2026-11)."""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import sdp  # noqa: E402
from protocols import FAMILIES, xiaomi  # noqa: E402
from protocols.sony_frame import T_DATA, encode as sony_encode  # noqa: E402


def make(family, name=""):
    sent = []
    proto = FAMILIES[family](sent.append, name)
    proto.start()
    return proto, sent


class SonyFrames(unittest.TestCase):
    def test_sequence_out_of_range_still_acks(self):
        proto, sent = make("sony", "WH-1000XM4")
        proto.receive(sony_encode(T_DATA, 5, b"\x01\x00"))
        self.assertTrue(sent)

    def test_one_byte_payloads(self):
        for op in (0x67, 0x23, 0xF7, 0x69, 0x13, 0x0B):
            for version in (1, 2):
                proto, _ = make("sony", "WH-1000XM4")
                proto.version = version
                proto.receive(sony_encode(T_DATA, 0, bytes([op])))


class XiaomiRecords(unittest.TestCase):
    def test_zero_length_record_stops(self):
        self.assertEqual(list(xiaomi.tlv(b"\x00\x07")), [])

    def test_info_reply_with_empty_record(self):
        proto, _ = make("xiaomi")
        body = b"\x00\x01" + b"\x00\x07"   # status, seq, then a 0-length record
        length = len(body)
        frame = xiaomi.HEAD + bytes([xiaomi.RESPONSE, xiaomi.OP_INFO]) + length.to_bytes(2, "big") + body + bytes([xiaomi.TAIL])
        proto.receive(frame)


class SdpReplies(unittest.TestCase):
    def test_truncated_pdus(self):
        for pdu in (b"", b"\x07", b"\x07\x00", b"\x07\x00\x01\x00\x05", b"\x07\x00\x01\x00\x05\x00\x09\x35"):
            with self.assertRaises(sdp.SdpError):
                sdp.split_response(pdu)

    def test_deep_nesting(self):
        # 1200 sequences, each holding the next (16-bit lengths): 3.6 KB
        data = b""
        for _ in range(1200):
            data = b"\x36" + len(data).to_bytes(2, "big") + data
        with self.assertRaises(sdp.SdpError):
            sdp.parse_element(data)

    def test_wrong_shapes_give_no_channel(self):
        # a top-level uint, and a channel that is a list instead of a uint
        self.assertIsNone(sdp.rfcomm_channel(b"\x09\x00\x04"))
        rfcomm_layer = b"\x35\x08\x19\x00\x03\x35\x03\x08\x05\x00"
        record = b"\x35\x10\x09\x00\x04\x35\x0b" + rfcomm_layer[:-1] + b"\x00"
        self.assertIsNone(sdp.rfcomm_channel(b"\x35" + bytes([len(record)]) + record))

    def test_channel_found(self):
        rfcomm = b"\x35\x05\x19\x00\x03\x08\x09"           # [RFCOMM, 9]
        descriptor = b"\x35" + bytes([len(rfcomm)]) + rfcomm
        record = b"\x09\x00\x04" + descriptor
        record = b"\x35" + bytes([len(record)]) + record
        lists = b"\x35" + bytes([len(record)]) + record
        self.assertEqual(sdp.rfcomm_channel(lists), 9)

    def test_channel_out_of_range(self):
        rfcomm = b"\x35\x05\x19\x00\x03\x08\x63"           # channel 99
        descriptor = b"\x35" + bytes([len(rfcomm)]) + rfcomm
        record = b"\x09\x00\x04" + descriptor
        record = b"\x35" + bytes([len(record)]) + record
        lists = b"\x35" + bytes([len(record)]) + record
        self.assertIsNone(sdp.rfcomm_channel(lists))

    def test_endless_continuation(self):
        class Sock:
            def __init__(self, *a):
                self.n = 0

            def settimeout(self, t):
                pass

            def connect(self, target):
                pass

            def send(self, data):
                pass

            def recv(self, size):
                self.n += 1
                cont = self.n.to_bytes(2, "big")
                return b"\x07\x00\x01\x00\x08\x00\x02\x35\x00" + bytes([len(cont)]) + cont

            def close(self):
                pass

        real = sdp.socket.socket
        sdp.socket.socket = Sock
        try:
            with self.assertRaises(sdp.SdpError):
                sdp.find_rfcomm_channel("00:00:00:00:00:00", "00000000-0000-0000-0000-000000000000")
        finally:
            sdp.socket.socket = real


if __name__ == "__main__":
    unittest.main()
