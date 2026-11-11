#!/usr/bin/env python3
"""Resident player of Orbit's volume tick: one output, one PipeWire stream.

usage: orbit_tick.py <sink node name> <mono 16-bit wav> [<filter link group>]

The stream is pacat's (pulseaudio-utils, on a default install where
pipewire-utils is not), aimed at the sink. WirePlumber sends a stream aimed at
a sink into the smart filter in front of it, and in Listen together the copies
read the monitor of the source's filter, so a tick sent through that filter
would be heard in every copy. The stream therefore carries the filter's own
link group (the third argument, Route.tickGroup): WirePlumber takes it as the
filter's own and sends it where the filter goes, the sink itself, so the tick
sounds in this output alone.

A tick per process (pw-play) costs a process start, a connection and a stream
per tick: at the 40 ticks a second of the time that was half a core. This helper opens ONE
stream (pacat, raw PCM on its standard input) and mixes the ticks into it:
every line "t" or "t <gain>" on the standard input plays one tick (gain 0..1,
the cap the caller derives from the output's level). Ticks are live, never
queued: a tick replaces the one still ringing, which is faded out in a few
milliseconds, and the lines of one read count as a single tick, the last one.
So two ticks never sum into a clip and nothing rings on after the last step.
It writes only while a tick rings and sleeps in select() the rest of the time,
so nothing runs between two bursts.

It dies with the shell (value 12): the end of its standard input, or SIGTERM,
closes the stream and exits; pacat then also reads end of file and goes.
Standard library only, no network, nothing written to disk.
"""
import array
import math
import os
import re
import select
import signal
import subprocess
import sys
import time
import wave

RATE = 48000
# One write is 10 ms of sound: short enough to start a tick within ~10 ms and
# to keep the stream's queue small, long enough to wake 100 times a second only
CHUNK = RATE // 100
# What pacat is asked to buffer: ticks reach the speaker about this late
LATENCY_MS = 20
# Each tick fades in and out (1.5 ms, 5 ms) so it starts and ends without a
# click; a tick replaced while it rings fades out over FADE samples (5 ms), long
# enough that the cut is not heard as a crackle
ATTACK = 72
RELEASE = 240
FADE = 240
# The shipped sound peaks near -10 dBFS: scaled to this share it peaks near
# -16 dBFS, so that even with the tick it replaces still fading the sum stays
# under -12 dBFS and a loud output has room left (no saturation)
HEADROOM = 0.5
# Longest line kept while waiting for its end: a tick line is a few bytes
MAX_LINE = 64
# The link group of Orbit's own filters (Route.filterArgs, wiredFilterArgs):
# anything else is ignored, so no other text reaches a stream property
GROUP = re.compile(r"orbit_(pc|wired)_[A-Za-z0-9_]{1,60}")


def load(path):
    """The samples of a mono 48 kHz 16-bit wav, as an array of shorts."""
    with wave.open(path) as w:
        if (w.getnchannels(), w.getsampwidth(), w.getframerate()) != (1, 2, RATE):
            raise ValueError("expected mono 16-bit 48 kHz")
        samples = array.array("h")
        samples.frombytes(w.readframes(w.getnframes()))
    for i in range(len(samples)):
        samples[i] = int(samples[i] * HEADROOM)
    for i in range(min(ATTACK, len(samples))):
        samples[i] = samples[i] * i // ATTACK
    for i in range(min(RELEASE, len(samples))):
        samples[-1 - i] = samples[-1 - i] * i // RELEASE
    return samples


def parse_gain(line):
    """The gain of a "t" or "t <gain>" line, 0..1; None for any other line."""
    parts = line.split()
    if not parts or parts[0] != b"t" or len(parts) > 2:
        return None
    if len(parts) == 1:
        return 1.0
    try:
        gain = float(parts[1])
    except ValueError:
        return 1.0
    return max(0.0, min(1.0, gain)) if math.isfinite(gain) else 1.0


def replace(voices, gain, delay):
    """Starts a tick and sets the ones still ringing fading out (one at a time)."""
    for voice in voices:
        voice[3] = voice[3] or FADE
    voices.append([0, delay, gain, 0])


def mix(sound, voices):
    """Next CHUNK samples of the voices (each [position, delay, gain, fade]) as bytes.

    A voice that starts inside the chunk has `delay` silent samples first, so
    a tick lands where it was asked for and not on the next chunk edge. A
    voice with a `fade` left is being replaced: it ramps to silence over those
    samples and goes. The voices are advanced; the finished ones are dropped.
    """
    total = [0] * CHUNK
    alive = []
    for voice in voices:
        position, delay, gain, fade = voice
        take = min(len(sound) - position, CHUNK - delay)
        if fade:
            take = min(take, fade)
        part = [s * gain for s in sound[position:position + take]]
        if fade:
            part = [s * (fade - i) / FADE for i, s in enumerate(part)]
        for i, s in enumerate(part):
            total[delay + i] += int(s)
        fade = max(0, fade - take) if fade else 0
        if position + take < len(sound) and (fade or not voice[3]):
            alive.append([position + take, 0, gain, fade])
    voices[:] = alive
    try:
        return array.array("h", total).tobytes()
    except OverflowError:
        # Never expected (one tick and a fading one); clip rather than wrap around
        return array.array("h", (max(-32768, min(32767, s)) for s in total)).tobytes()


def player_args(sink, group, name):
    """The pacat command of the one stream: raw s16 mono on its standard input, into `sink`.

    WirePlumber sends a stream aimed at a sink into the smart filter that
    targets it, whatever the stream asks (NAK-251: the copies read that
    filter's monitor). A stream that shares the filter's node.link-group is
    taken as the filter's own and goes where the filter goes, the sink itself,
    so the tick stays in that output alone. Thanks to WirePlumber's
    smart-filter rules for that behaviour (find-filter-target.lua, read, not
    copied). Nothing is remembered (restore-props, restore-target), and the
    stream never falls back or moves to another output: a tick to a sink that
    is missing or goes away ends instead of playing on the default output.
    The volume is set to 100 %: without it pacat's stream starts at 0 % here
    (pactl shows "mono: 0 / 0%") and the tick is silent. restore-props=false
    only keeps this level from being stored; it does not set one.
    """
    args = ["pacat", "--playback", "--raw", "--format=s16le", f"--rate={RATE}", "--channels=1",
            f"--latency-msec={LATENCY_MS}", "--volume=65536", "-d", sink,
            "--client-name=Orbit", "--stream-name=Volume tick",
            f"--property=node.name={name}",
            "--property=state.restore-props=false", "--property=state.restore-target=false",
            "--property=node.dont-reconnect=true", "--property=node.dont-fallback=true"]
    if group and GROUP.fullmatch(group):
        args.append(f"--property=node.link-group={group}")
    return args


def main(sink, path, group=""):
    sound = load(path)
    name = f"orbit_tick_{os.getpid()}"
    try:
        out = subprocess.Popen(player_args(sink, group, name), stdin=subprocess.PIPE,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        # No pacat (pulseaudio-utils left out): the tick stays silent, never an error
        return
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    voices = []
    fd = sys.stdin.fileno()
    open_input = True
    deadline = 0.0
    pending = b""
    try:
        while open_input or voices:
            # Idle: wait for a line for ever; ringing: only until the next chunk is due
            wait = max(0.0, deadline - time.monotonic()) if voices else None
            if open_input and select.select([fd], [], [], wait)[0]:
                data = os.read(fd, 4096)
                if not data:
                    open_input = False
                lines = (pending + data).split(b"\n")
                pending = lines.pop()[-MAX_LINE:]
                gains = [g for g in map(parse_gain, lines) if g is not None]
                if gains:
                    now = time.monotonic()
                    if not voices:
                        deadline = now + CHUNK / RATE
                    # The chunk due at `deadline` began CHUNK samples before it
                    start = int((now - deadline) * RATE) + CHUNK
                    # Live: only the last tick of the read plays
                    replace(voices, gains[-1], max(0, min(CHUNK - 1, start)))
                continue
            if voices:
                out.stdin.write(mix(sound, voices))
                out.stdin.flush()
                deadline += CHUNK / RATE
    except (BrokenPipeError, OSError):
        # The output went away mid-burst (a device that disconnected): nothing to say, nothing left ringing
        pass
    finally:
        try:
            out.stdin.close()
        except OSError:
            pass
        try:
            out.wait(timeout=1)
        except subprocess.TimeoutExpired:
            out.kill()


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
