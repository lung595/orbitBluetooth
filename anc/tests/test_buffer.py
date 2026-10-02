"""A device sending endless bytes without a frame end cannot make the
helper grow without limit (P117)."""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from protocols import haylou  # noqa: E402


class Buffer(unittest.TestCase):
    def test_garbage_is_capped(self):
        p = haylou.Haylou(lambda data: None)
        for _ in range(32):
            p.receive(b"\x00" * 65536)
        self.assertLessEqual(len(p.buffer), p.MAX_BUFFER)

    def test_frames_still_parsed_after_garbage(self):
        p = haylou.Haylou(lambda data: None)
        seen = []
        p.handle = seen.append
        p.receive(b"\x00" * 200000)
        p.receive(haylou.HEAD + b"\x01\x02" + haylou.TAIL)
        self.assertEqual(len(seen), 1)


if __name__ == "__main__":
    unittest.main()
