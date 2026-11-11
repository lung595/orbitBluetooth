import array
import os
import re
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


class PlayerArgsTest(unittest.TestCase):
    group = "orbit_pc_AA_BB_CC_DD_EE_FF"

    def args(self, group=""):
        return t.player_args("fake.sink", group, "orbit_tick_7")

    def test_the_stream_is_aimed_at_the_sink(self):
        args = self.args()
        self.assertEqual(args[0], "pacat")
        self.assertEqual(args[args.index("-d") + 1], "fake.sink")

    def test_nothing_is_remembered_and_it_never_moves_to_another_output(self):
        # --volume=65536 is not redundant: without it the stream starts at 0 % and the tick is silent
        for wanted in ("--property=state.restore-props=false", "--property=state.restore-target=false",
                       "--property=node.dont-reconnect=true", "--property=node.dont-fallback=true", "--volume=65536"):
            self.assertIn(wanted, self.args())

    def test_the_filter_link_group_goes_last(self):
        self.assertEqual(self.args(self.group)[-1], "--property=node.link-group=" + self.group)
        self.assertEqual(t.player_args("s", "orbit_wired_w_card_0123abcd", "n")[-1], "--property=node.link-group=orbit_wired_w_card_0123abcd")

    def test_no_group_or_a_bad_one_sets_none(self):
        for bad in ("", "x y", "orbit_pc_a,b", "node.autoconnect=false", "orbit_pc_A B", "other_AA"):
            self.assertFalse([a for a in self.args(bad) if "link-group" in a], bad)

    def test_autoconnect_is_never_touched(self):
        for group in ("", self.group, "node.autoconnect=false"):
            self.assertFalse([a for a in self.args(group) if "autoconnect" in a])


class SessionTest(unittest.TestCase):
    """The whole helper against a stand-in pacat that keeps what it is sent."""

    helper = os.path.join(os.path.dirname(__file__), "..", "orbit_tick.py")
    wav = os.path.join(os.path.dirname(__file__), "..", "..", "sounds", "volume.wav")

    def fake(self, tmp, body):
        path = os.path.join(tmp, "pacat")
        with open(path, "w") as f:
            f.write("#!/bin/sh\n" + body)
        os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR)
        return dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"])

    def test_ticks_become_sound_and_the_end_of_input_ends_it_all(self):
        with tempfile.TemporaryDirectory() as tmp:
            sink = os.path.join(tmp, "got.raw")
            env = self.fake(tmp, "printf '%s\\n' \"$@\" > " + tmp + "/args\nexec cat > " + sink + "\n")
            proc = subprocess.run(
                [sys.executable, "-E", "-s", self.helper, "fake.sink", self.wav, "orbit_pc_AA_BB_CC_DD_EE_FF"],
                input=b"t\nt\n", env=env, timeout=10, capture_output=True)
            self.assertEqual(proc.returncode, 0)
            with open(sink, "rb") as f:
                data = shorts(f.read())
            with open(os.path.join(tmp, "args")) as f:
                args = f.read().splitlines()
        # Aimed at the sink, in the filter's link group, and WirePlumber still places it (no autoconnect)
        self.assertEqual(args[args.index("-d") + 1], "fake.sink")
        self.assertIn("--property=node.link-group=orbit_pc_AA_BB_CC_DD_EE_FF", args)
        self.assertFalse([a for a in args if "autoconnect" in a])
        # The two lines made one tick, then it stopped writing (whole chunks only)
        self.assertGreater(max(map(abs, data)), 1000)
        self.assertEqual(len(data) % t.CHUNK, 0)
        self.assertLess(len(data), t.RATE)

    def test_an_output_that_vanishes_ends_quietly(self):
        with tempfile.TemporaryDirectory() as tmp:
            # pacat's own answer to a sink that is not there ("No such entity")
            env = self.fake(tmp, "exit 1\n")
            proc = subprocess.run([sys.executable, "-E", "-s", self.helper, "gone.sink", self.wav],
                                  input=b"t 0.5\n", env=env, timeout=10, capture_output=True)
        self.assertEqual((proc.returncode, proc.stderr), (0, b""))

    def test_no_pacat_ends_quietly(self):
        with tempfile.TemporaryDirectory() as tmp:
            # A PATH with python and nothing else: pacat cannot be started
            os.symlink(sys.executable, os.path.join(tmp, "python3"))
            proc = subprocess.run([sys.executable, "-E", "-s", self.helper, "fake.sink", self.wav],
                                  input=b"t\n", env=dict(os.environ, PATH=tmp), timeout=10, capture_output=True)
        self.assertEqual((proc.returncode, proc.stderr), (0, b""))


def gate_times(events_per_s, seconds, gap_ms):
    """Times (s) at which a gate of gap_ms lets a tick through, late ones dropped.

    A model of Volume.due (the real one is exercised in tests/volume.test.js); the
    gap itself is read from Volume.js, so this only proves what the constant yields.
    """
    out, last = [], None
    for k in range(int(events_per_s * seconds)):
        now = k / events_per_s
        if last is None or now - last >= gap_ms / 1000:
            out.append(now)
            last = now
    return out


def render(sound, starts, seconds):
    """What the helper writes for ticks asked at `starts` (s): samples, most voices at once."""
    samples, voices, most = [], [], 0
    pending = list(starts)
    for c in range(int(seconds * t.RATE) // t.CHUNK):
        begin = c * t.CHUNK
        while pending and pending[0] * t.RATE < begin + t.CHUNK:
            t.replace(voices, 1.0, max(0, int(pending.pop(0) * t.RATE) - begin))
        most = max(most, len(voices))
        samples += shorts(t.mix(sound, voices))
    return samples, most


class BurstTest(unittest.TestCase):
    """A wheel spun at full speed (240 events a second) must not saturate or crackle."""

    @classmethod
    def setUpClass(cls):
        root = os.path.join(os.path.dirname(__file__), "..", "..")
        with open(os.path.join(root, "components", "volume", "Volume.js")) as f:
            gap = int(re.search(r"var MIN_GAP_MS = (\d+);", f.read()).group(1))
        cls.starts = gate_times(240, 1.0, gap)
        cls.sound = t.load(os.path.join(root, "sounds", "volume.wav"))
        cls.samples, cls.most = render(cls.sound, cls.starts, 1.3)

    def test_the_burst_stays_well_below_full_scale(self):
        # Spec: about -16 dBFS, never above -12 dBFS, even with a tick fading under the next
        self.assertLess(max(map(abs, self.samples)), 32768 * 10 ** (-12 / 20))

    def test_nothing_is_clipped(self):
        self.assertLess(max(map(abs, self.samples)), 32767)

    def test_ticks_start_at_most_20_a_second(self):
        self.assertGreaterEqual(min(b - a for a, b in zip(self.starts, self.starts[1:])), 0.05 - 1e-9)

    def test_at_most_the_tick_and_the_one_it_replaces_ring(self):
        self.assertLessEqual(self.most, 2)

    def test_no_step_between_two_samples_is_a_click(self):
        # A click is a jump the ear hears as a crackle: the loudest step must stay small
        step = max(abs(b - a) for a, b in zip(self.samples, self.samples[1:]))
        self.assertLess(step, 32768 * 10 ** (-20 / 20))


if __name__ == "__main__":
    unittest.main()
