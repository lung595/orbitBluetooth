"""Anker Soundcore over RFCOMM.

Written from the byte-level facts documented by OpenSCQ30 (no code
copied). Frame:

    direction (5) | command (2) | total length u16 LE | body | sum8

direction is 08 ee 00 00 00 from us and 09 ff 00 00 01 from the headset;
the length counts the whole frame. Sound modes are 4 bytes on most models
(ambient: 0 noise cancelling, 1 transparency, 2 normal; then the
cancelling and transparency sub-modes, then a custom level) and 6 bytes on
the Space Q45, which adds adaptive cancelling.

The state reply is model-specific, so only models whose layout is known
read their mode at connection; the others learn it from the first change.
"""

import re

from .base import Protocol
from .checksums import sum8

SPP = "00001101-0000-1000-8000-00805f9b34fb"
OUT, IN = bytes.fromhex("08ee000000"), bytes.fromhex("09ff000001")

REQUEST_STATE, BATTERY_LEVEL, BATTERY_CHARGING = b"\x01\x01", b"\x01\x03", b"\x01\x04"
SET_MODES, MODES_CHANGED = b"\x06\x81", b"\x06\x01"

AMBIENT_TO_MODE = {0: "nc", 1: "ambient", 2: "off"}
MODE_TO_AMBIENT = {"nc": 0, "ambient": 1, "off": 2}

# Model -> (offset of the sound modes in the state reply, dual batteries)
LAYOUTS = [
    (re.compile(r"Life ?Q3[05]", re.I), 35, False),        # A3028, A3027
    (re.compile(r"Liberty Air 2 Pro", re.I), 77, True),    # A3951
    (re.compile(r"Space ?Q45", re.I), 49, False),          # A3040 (6-byte modes)
]


def encode(command, body=b""):
    raw = OUT + command + (len(OUT) + 2 + 2 + len(body) + 1).to_bytes(2, "little") + bytes(body)
    return raw + bytes([sum8(raw)])


class Soundcore(Protocol):
    transport = ("rfcomm", [SPP], None)
    ready_timeout = 3.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.offset, self.dual = next(((o, d) for rx, o, d in LAYOUTS if rx.search(name)), (None, False))
        self.v2 = bool(re.search(r"Space ?Q45", name, re.I))
        # Last known sound-mode bytes; defaults: outdoor cancelling, vocal
        self.modes = bytearray([2, 0x51, 1, 0, 0, 3] if self.v2 else [2, 1, 1, 0])
        self.features["modes"] = ["nc", "adaptive", "ambient", "off"] if self.v2 else ["nc", "ambient", "off"]

    def start(self):
        self.send(encode(REQUEST_STATE))

    def frames(self):
        while True:
            start = self.buffer.find(IN)
            if start < 0:
                del self.buffer[:max(0, len(self.buffer) - 4)]
                return
            del self.buffer[:start]
            if len(self.buffer) < 10:
                return
            total = int.from_bytes(self.buffer[7:9], "little")
            if total < 10:
                del self.buffer[:1]
                continue
            if len(self.buffer) < total:
                return
            raw = bytes(self.buffer[:total])
            if sum8(raw[:-1]) != raw[-1]:
                del self.buffer[:1]
                continue
            del self.buffer[:total]
            yield raw[5:7], raw[9:-1]

    def handle(self, packet):
        command, body = packet
        if command == REQUEST_STATE:
            self._on_state(body)
        elif command == MODES_CHANGED:
            self._on_modes(body)
        elif command == BATTERY_LEVEL and body:
            self._on_battery(body, None)
        elif command == BATTERY_CHARGING and body:
            self._on_battery(None, body)

    def _on_state(self, body):
        if self.offset is not None and len(body) >= self.offset + len(self.modes):
            self._on_modes(body[self.offset:self.offset + len(self.modes)])
            if self.dual and len(body) > 5:
                self.set_battery("left", body[2] * 20, body[4])
                self.set_battery("right", body[3] * 20, body[5])
            elif not self.dual:
                self.set_battery("single", body[0] * 20, body[1])
        self.mark_ready()

    def _on_modes(self, body):
        if len(body) < len(self.modes):
            return
        self.modes[:] = body[:len(self.modes)]
        mode = AMBIENT_TO_MODE.get(self.modes[0])
        if mode == "nc" and self.v2 and self.modes[3] == 1:
            mode = "adaptive"
        self.state["mode"] = mode

    def _on_battery(self, levels, charging):
        # Levels are 0..5 steps (x20 = percent); dual models send left, right
        if levels:
            names = ["left", "right"] if len(levels) >= 2 else ["single"]
            for part, value in zip(names, levels):
                old = self.state["battery"].get(part, {})
                self.set_battery(part, value * 20, old.get("charging", False))
        if charging:
            names = ["left", "right"] if len(charging) >= 2 else ["single"]
            for part, value in zip(names, charging):
                old = self.state["battery"].get(part)
                if old:
                    old["charging"] = bool(value)

    def set_mode(self, mode):
        # Only the ambient byte changes (a sub-mode change would need the
        # firmware's three-step dance); the Q45 also switches manual/adaptive
        self.modes[0] = MODE_TO_AMBIENT["nc" if mode == "adaptive" else mode]
        if self.v2 and mode in ("nc", "adaptive"):
            self.modes[3] = 1 if mode == "adaptive" else 0
        self.send(encode(SET_MODES, bytes(self.modes)))
        self.state["mode"] = mode

    def refresh(self):
        self.send(encode(REQUEST_STATE))
