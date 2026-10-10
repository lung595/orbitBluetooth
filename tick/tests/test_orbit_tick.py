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


class LinkTest(unittest.TestCase):
    outs = ["orbit_tick_7:output_MONO", "other_node:output_FL"]
    ins = ["sink.1:playback_FL", "sink.1:playback_FR", "sink.12:playback_FL", "orbit_pc_x:playback_FL"]

    def test_the_stream_is_linked_to_each_input_of_the_sink_itself(self):
        self.assertEqual(
            t.link_plan(self.outs, self.ins, "orbit_tick_7", "sink.1"),
            [("orbit_tick_7:output_MONO", "sink.1:playback_FL"), ("orbit_tick_7:output_MONO", "sink.1:playback_FR")])

    def test_never_the_filter_in_front_of_the_sink(self):
        pairs = t.link_plan(self.outs, self.ins, "orbit_tick_7", "sink.1")
        self.assertFalse([p for p in pairs if p[1].startswith("orbit_pc_x:")])

    def test_nothing_is_linked_until_both_ends_exist(self):
        self.assertEqual(t.link_plan([], self.ins, "orbit_tick_7", "sink.1"), [])
        self.assertEqual(t.link_plan(self.outs, self.ins, "orbit_tick_7", "gone.sink"), [])


class SessionTest(unittest.TestCase):
    """The whole helper against a stand-in pw-cat that keeps what it is sent."""

    def test_ticks_become_sound_and_the_end_of_input_ends_it_all(self):
        with tempfile.TemporaryDirectory() as tmp:
            sink = os.path.join(tmp, "got.raw")
            fake = os.path.join(tmp, "pw-cat")
            with open(fake, "w") as f:
                f.write("#!/bin/sh\necho \"$@\" > " + tmp + "/args\nexec cat > " + sink + "\n")
            os.chmod(fake, os.stat(fake).st_mode | stat.S_IXUSR)
            # A stand-in pw-link that lists the stream (named as pw-cat was asked) and the sink's ports
            links = os.path.join(tmp, "pw-link")
            with open(links, "w") as f:
                f.write("#!/bin/sh\ncase \"$1\" in\n"
                        "-o) n=$(sed -n 's/.*node.name=\\([^,]*\\),.*/\\1/p' " + tmp + "/args); echo \"$n:output_MONO\";;\n"
                        "-i) echo fake.sink:playback_FL; echo fake.sink:playback_FR;;\n"
                        "*) echo \"$@\" >> " + tmp + "/links;;\nesac\n")
            os.chmod(links, os.stat(links).st_mode | stat.S_IXUSR)
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"])
            wav = os.path.join(os.path.dirname(__file__), "..", "..", "sounds", "volume.wav")
            proc = subprocess.run(
                [sys.executable, "-E", "-s", os.path.join(os.path.dirname(__file__), "..", "orbit_tick.py"), "fake.sink", wav],
                input=b"t\nt\n", env=env, timeout=10, capture_output=True)
            self.assertEqual(proc.returncode, 0)
            with open(sink, "rb") as f:
                data = shorts(f.read())
            with open(os.path.join(tmp, "links")) as f:
                made = [line.split() for line in f]
            with open(os.path.join(tmp, "args")) as f:
                args = f.read()
        # Autoconnect is off and the stream is linked to the sink's two inputs by hand
        self.assertIn("node.autoconnect=false", args)
        self.assertEqual([m[2] for m in made], ["fake.sink:playback_FL", "fake.sink:playback_FR"])
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
            # Never the real pw-link: it would read the live graph
            with open(os.path.join(tmp, "pw-link"), "w") as f:
                f.write("#!/bin/sh\nexit 0\n")
            os.chmod(os.path.join(tmp, "pw-link"), 0o755)
            env = dict(os.environ, PATH=tmp + os.pathsep + os.environ["PATH"])
            wav = os.path.join(os.path.dirname(__file__), "..", "..", "sounds", "volume.wav")
            proc = subprocess.run(
                [sys.executable, "-E", "-s", os.path.join(os.path.dirname(__file__), "..", "orbit_tick.py"), "gone.sink", wav],
                input=b"t 0.5\n", env=env, timeout=10, capture_output=True)
        self.assertEqual((proc.returncode, proc.stderr), (0, b""))


if __name__ == "__main__":
    unittest.main()


def gate_times(events_per_s, seconds, gap_ms):
    """Times (s) at which VolumeTick.qml lets a tick through: a live gate, late ones dropped."""
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
        # Spec: about -18 dBFS, never above -12 dBFS, even with a tick fading under the next
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
