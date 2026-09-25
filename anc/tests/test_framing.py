"""Frames and checksums, checked against the vectors published in the
protocol documentation (and, for SAFER+, a reference implementation)."""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from protocols import safer, samsung, sony, soundcore, nothing  # noqa: E402
from protocols.apple import control  # noqa: E402
from protocols.checksums import crc16_modbus, crc16_xmodem  # noqa: E402


def h(text):
    return bytes.fromhex(text.replace(" ", ""))


class Checksums(unittest.TestCase):
    def test_xmodem_galaxybudsclient_vector(self):
        # Vector from GalaxyBudsClient's Crc16.cs comment
        self.assertEqual(crc16_xmodem(h("61 02 00 4B 5F 01 00 00 00 01 05 00 02 00 13")).to_bytes(2, "little"), h("0F F3"))

    def test_modbus_nothing_get_anc(self):
        self.assertEqual(crc16_modbus(h("55 20 01 1e c0 00 00 00")).to_bytes(2, "little"), h("31 19"))


class Frames(unittest.TestCase):
    def test_sony_xm6_commands(self):
        self.assertEqual(sony.encode(0x0C, 0, h("68 19 01 01 00 00 0a 00 00")), h("3e 0c 00 00 00 00 09 68 19 01 01 00 00 0a 00 00 a2 3c"))
        self.assertEqual(sony.encode(0x0C, 0, h("68 19 01 00 00 00 0a 00 00")), h("3e 0c 00 00 00 00 09 68 19 01 00 00 00 0a 00 00 a1 3c"))
        self.assertEqual(sony.encode(0x0C, 1, h("06 00")), h("3e 0c 01 00 00 00 02 06 00 15 3c"))

    def test_sony_decode_notification(self):
        frame = h("0c 00 00 00 00 09 69 19 01 01 01 00 0f 00 00 a9")
        self.assertEqual(sony.decode(frame), (0x0C, 0, h("69 19 01 01 01 00 0f 00 00")))

    def test_apple_control(self):
        self.assertEqual(control(0x0D, 0x02), h("04 00 04 00 09 00 0D 02 00 00 00"))

    def test_nothing_set_transparency(self):
        # Verified capture from cmfctl (control 0x0160, seq 1)
        self.assertEqual(nothing.encode(0xF00F, h("01 07 00"), 1), h("55 60 01 0f f0 03 00 01 01 07 00 fa 77"))

    def test_samsung(self):
        buds = samsung.Samsung(lambda d: None, "Galaxy Buds2 Pro")
        self.assertEqual(buds.encode(0x78, h("00")), h("fd 04 00 78 00 f0 81 dd"))
        self.assertEqual(buds.encode(0x78, h("02")), h("fd 04 00 78 02 b2 a1 dd"))
        self.assertEqual(buds.encode(0x7A, h("01")), h("fd 04 00 7a 01 b3 f7 dd"))

    def test_soundcore(self):
        self.assertEqual(soundcore.encode(h("01 01")), h("08 ee 00 00 00 01 01 0a 00 02"))
        self.assertEqual(soundcore.encode(h("06 81"), h("02 00 01 00")), h("08 ee 00 00 00 06 81 0e 00 02 00 01 00 8e"))


class Safer(unittest.TestCase):
    # Answers computed by Gadgetbridge's Java implementation for the same challenges
    VECTORS = {
        "00000000000000000000000000000000": "bca5905bc849392e7bf9fdcdc570ef77",
        "0123456789abcdef0011223344556677": "3e09c46ecdbe306a40025abac8f9971a",
        "ffeeddccbbaa99887766554433221100": "507ed059421c0502b083c60cbf7f08df",
    }

    def test_vectors(self):
        for challenge, answer in self.VECTORS.items():
            self.assertEqual(safer.respond(bytes.fromhex(challenge)).hex(), answer)

    def test_tables(self):
        self.assertEqual(safer.EXP[128], 0)     # 45^128 = 256 = "0"
        self.assertEqual(safer.LOG[0], 128)
        self.assertTrue(all(safer.LOG[safer.EXP[x]] == x for x in range(256)))


if __name__ == "__main__":
    unittest.main()
