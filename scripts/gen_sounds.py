#!/usr/bin/env python3
"""Synthesizes the plugin's UI sounds (short, soft, glassy chimes).

Pure standard library so it can be re-run anywhere:
    python3 scripts/gen_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 48000
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")


def tone(freq, dur, start, buf, gain=0.5, attack=0.004, decay=9.0, bell=0.28):
    """Adds a bell-ish partial stack with an exponential decay into buf."""
    n0 = int(start * RATE)
    for i in range(int(dur * RATE)):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        s = math.sin(2 * math.pi * freq * t)
        s += bell * math.sin(2 * math.pi * freq * 2.76 * t) * math.exp(-decay * 2.2 * t)
        s += 0.12 * math.sin(2 * math.pi * freq * 5.4 * t) * math.exp(-decay * 4 * t)
        idx = n0 + i
        if idx < len(buf):
            buf[idx] += gain * env * s


def write(name, buf, peak=0.32):
    m = max(1e-9, max(abs(v) for v in buf))
    fade = int(0.006 * RATE)
    for i in range(fade):
        buf[-1 - i] *= i / fade
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(v / m * peak * 32767)) for v in buf))


def empty(sec):
    return [0.0] * int(sec * RATE)


os.makedirs(OUT, exist_ok=True)

# Connect: two rising notes (E6 -> B6), the second one rings a little longer.
b = empty(0.42)
tone(1318.5, 0.2, 0.0, b, gain=0.55, decay=18)
tone(1975.5, 0.4, 0.075, b, gain=0.6, decay=9)
write("connect.wav", b)

# Disconnect: the mirror image, softer and lower (B5 -> E5).
b = empty(0.38)
tone(987.8, 0.18, 0.0, b, gain=0.5, decay=18)
tone(659.3, 0.36, 0.07, b, gain=0.5, decay=11)
write("disconnect.wav", b, peak=0.26)

# Snap: tiny magnetic "tick" when a device locks into the connect zone.
b = empty(0.06)
tone(2637.0, 0.05, 0.0, b, gain=0.7, attack=0.0015, decay=70, bell=0.1)
random.seed(7)
for i in range(int(0.004 * RATE)):
    b[i] += (random.random() * 2 - 1) * 0.25 * (1 - i / (0.004 * RATE))
write("snap.wav", b, peak=0.22)

# Error: two muted low blips.
b = empty(0.3)
tone(392.0, 0.12, 0.0, b, gain=0.6, decay=26, bell=0.08)
tone(349.2, 0.16, 0.11, b, gain=0.6, decay=22, bell=0.08)
write("error.wav", b, peak=0.26)
