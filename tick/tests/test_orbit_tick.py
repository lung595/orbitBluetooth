import array
import os
import stat
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import orbit_tick as t


def shorts(raw):
    out = array.array("h")
    out.frombytes(raw)
    return list(out)


class MixTest(unittest.TestCase):
    sound = array.array("h", [100] * (t.CHUNK + 5))

    def test_one_voice_is_copied_then_ends(self):
        voices = [[0, 0]]
        first = shorts(t.mix(self.sound, voices))
        self.assertEqual(first, [100] * t.CHUNK)
        self.assertEqual(voices, [[t.CHUNK, 0]])
        second = shorts(t.mix(self.sound, voices))
        self.assertEqual(second[:5], [100] * 5)
        self.assertEqual(second[5:], [0] * (t.CHUNK - 5))
        self.assertEqual(voices, [])

    def test_a_late_voice_starts_after_its_delay(self):
        out = shorts(t.mix(self.sound, [[0, 40]]))
        self.assertEqual(out[:40], [0] * 40)
        self.assertEqual(out[40], 100)

    def test_voices_add_up(self):
        out = shorts(t.mix(self.sound, [[0, 0], [0, 10]]))
        self.assertEqual((out[0], out[10]), (100, 200))

    def test_loud_voices_clip_instead_of_wrapping(self):
        loud = array.array("h", [30000] * t.CHUNK)
        out = shorts(t.mix(loud, [[0, 0], [0, 0]]))
        self.assertEqual(set(out), {32767})

    def test_shipped_sound_is_playable(self):
        path = os.path.join(os.path.dirname(__file__), "..", "..", "sounds", "volume.wav")
        self.assertEqual(len(t.load(path)), 3360)


class SessionTest(unittest.TestCase):
    """The whole helper against a stand-in pw-cat that keeps what it is sent."""

    def test_ticks_become_sound_and_the_end_of_input_ends_it_all(self):
        with tempfile.TemporaryDirectory() as tmp:
            sink = os.path.join(tmp, "got.raw")
            fake = os.path.join(tmp, "pw-cat")
            with open(fake, "w") as f:
                f.write("#!/bin/sh\nexec cat > " + sink + "\n")
            os.chmod(fake, os.stat(fake).st_mode | stat.S_IXUSR)
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"])
            wav = os.path.join(os.path.dirname(__file__), "..", "..", "sounds", "volume.wav")
            proc = subprocess.run(
                [sys.executable, "-E", "-s", os.path.join(os.path.dirname(__file__), "..", "orbit_tick.py"), "fake.sink", wav],
                input=b"t\nt\n", env=env, timeout=10, capture_output=True)
            self.assertEqual(proc.returncode, 0)
            with open(sink, "rb") as f:
                data = shorts(f.read())
        # Two ticks sounded, then it stopped writing (whole chunks only)
        self.assertGreater(max(map(abs, data)), 1000)
        self.assertEqual(len(data) % t.CHUNK, 0)
        self.assertLess(len(data), t.RATE)


if __name__ == "__main__":
    unittest.main()
