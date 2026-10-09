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
        voices = [[0, 0, 1.0, 0]]
        first = shorts(t.mix(self.sound, voices))
        self.assertEqual(first, [100] * t.CHUNK)
        self.assertEqual(voices, [[t.CHUNK, 0, 1.0, 0]])
        second = shorts(t.mix(self.sound, voices))
        self.assertEqual(second[:5], [100] * 5)
        self.assertEqual(second[5:], [0] * (t.CHUNK - 5))
        self.assertEqual(voices, [])

    def test_a_late_voice_starts_after_its_delay(self):
        out = shorts(t.mix(self.sound, [[0, 40, 1.0, 0]]))
        self.assertEqual(out[:40], [0] * 40)
        self.assertEqual(out[40], 100)

    def test_the_gain_scales_the_tick(self):
        out = shorts(t.mix(self.sound, [[0, 0, 0.5, 0]]))
        self.assertEqual(set(out), {50})

    def test_a_replaced_tick_fades_out_then_goes(self):
        voices = [[0, 0, 1.0, 0]]
        t.replace(voices, 1.0, 0)
        self.assertEqual([v[3] for v in voices], [t.FADE, 0])
        out = shorts(t.mix(self.sound, voices[:1]))
        self.assertEqual(out[0], 100)
        self.assertLess(out[t.FADE - 1], 3)
        self.assertEqual(set(out[t.FADE:]), {0})

    def test_a_replacement_never_leaves_more_than_two_voices(self):
        voices = []
        for _ in range(5):
            t.replace(voices, 1.0, 0)
            t.mix(self.sound, voices)
        self.assertLessEqual(len(voices), 2)

    def test_the_tick_and_the_one_it_replaces_do_not_clip(self):
        loud = array.array("h", [20000] * (t.CHUNK * 3))
        voices = []
        t.replace(voices, 1.0, 0)
        t.mix(loud, voices)
        t.replace(voices, 1.0, 0)
        out = shorts(t.mix(loud, voices))
        self.assertLessEqual(max(out), 32767)

    def test_shipped_sound_is_playable_and_fades_at_both_ends(self):
        path = os.path.join(os.path.dirname(__file__), "..", "..", "sounds", "volume.wav")
        sound = t.load(path)
        self.assertEqual(len(sound), 3360)
        self.assertEqual((sound[0], sound[-1]), (0, 0))
        self.assertLess(abs(sound[1]), abs(sound[t.ATTACK]))


class GainTest(unittest.TestCase):
    def test_lines(self):
        self.assertEqual(t.parse_gain(b"t"), 1.0)
        self.assertEqual(t.parse_gain(b"t 0.6"), 0.6)

    def test_the_gain_is_capped_to_zero_one(self):
        self.assertEqual((t.parse_gain(b"t 7"), t.parse_gain(b"t -1")), (1.0, 0.0))

    def test_a_broken_gain_is_a_plain_tick_and_other_lines_are_nothing(self):
        self.assertEqual((t.parse_gain(b"t nan"), t.parse_gain(b"t x")), (1.0, 1.0))
        self.assertEqual([t.parse_gain(b""), t.parse_gain(b"x"), t.parse_gain(b"t 1 2")], [None, None, None])


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
        # The two lines made one tick, then it stopped writing (whole chunks only)
        self.assertGreater(max(map(abs, data)), 1000)
        self.assertEqual(len(data) % t.CHUNK, 0)
        self.assertLess(len(data), t.RATE)

    def test_an_output_that_vanishes_ends_quietly(self):
        with tempfile.TemporaryDirectory() as tmp:
            fake = os.path.join(tmp, "pw-cat")
            with open(fake, "w") as f:
                f.write("#!/bin/sh\nexit 0\n")
            os.chmod(fake, os.stat(fake).st_mode | stat.S_IXUSR)
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"])
            wav = os.path.join(os.path.dirname(__file__), "..", "..", "sounds", "volume.wav")
            proc = subprocess.run(
                [sys.executable, "-E", "-s", os.path.join(os.path.dirname(__file__), "..", "orbit_tick.py"), "gone.sink", wav],
                input=b"t 0.5\n", env=env, timeout=10, capture_output=True)
        self.assertEqual((proc.returncode, proc.stderr), (0, b""))


if __name__ == "__main__":
    unittest.main()
