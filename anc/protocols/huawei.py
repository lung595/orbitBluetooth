"""Huawei and Honor earbuds/headphones (FreeBuds, FreeLace, FreeClip).

Written from the byte-level facts documented by OpenFreebuds and
Gadgetbridge (no code copied). Frame:

    5A | length u16 BE (body + 1) | 00 | service | command | TLV... | CRC16 BE

TLV parameters are (type, length, value); the CRC (CRC-16/XMODEM) covers
everything before it. Noise control: read 2B 2A, set 2B 04; parameter 1
is (level, mode) with mode 0 off, 1 cancelling, 2 awareness.
"""

import re

from .base import Protocol
from .checksums import crc16_xmodem

SPP = "00001101-0000-1000-8000-00805f9b34fb"

ANC_READ, ANC_SET, ANC_CHANGED_LEGACY = b"\x2b\x2a", b"\x2b\x04", b"\x2b\x03"
BATTERY_READ, BATTERY_NOTIFY = b"\x01\x08", b"\x01\x27"

BYTE_TO_MODE = {0: "off", 1: "nc", 2: "ambient"}
LEVEL_NORMAL, LEVEL_DYNAMIC = 0, 3          # cancelling levels
VOICE_ON, VOICE_OFF = 1, 2                  # awareness levels

NO_ANC = re.compile(r"FreeBuds (3|SE|SE 2)$|FreeClip 2", re.I)
DYNAMIC = re.compile(r"FreeBuds (5i|6i|Pro|Pro [345]|SE 4|Studio)|FreeLace Pro 2|FreeClip$", re.I)
VOICE = re.compile(r"FreeBuds (Pro|Pro [345]|Studio)$|FreeLace Pro 2|FreeClip$", re.I)
NO_TWS = re.compile(r"Studio|FreeLace", re.I)


def tlv(params):
    out = b""
    for ptype, value in params:
        out += bytes([ptype, len(value)]) + value
    return out


def encode(command, params):
    body = command + tlv(params)
    raw = b"\x5a" + (len(body) + 1).to_bytes(2, "big") + b"\x00" + body
    return raw + crc16_xmodem(raw).to_bytes(2, "big")


def parse_params(data):
    params, i = {}, 0
    while i + 2 <= len(data):
        ptype, length = data[i], data[i + 1]
        params[ptype] = data[i + 2:i + 2 + length]
        i += 2 + length
    return params


class Huawei(Protocol):
    # Recent models use channel 1, older ones (4i, 5i, SE, FreeLace Pro) 16
    transport = ("rfcomm", [SPP], [1, 16])
    ready_timeout = 3.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.level = LEVEL_NORMAL
        self.hw_mode = 0
        if not NO_ANC.search(name):
            modes = ["nc", "ambient", "off"]
            if DYNAMIC.search(name):
                modes.insert(1, "adaptive")
            self.features["modes"] = modes
            self.features["voice"] = bool(VOICE.search(name))

    def start(self):
        if self.features["modes"]:
            self.send(encode(ANC_READ, [(1, b""), (2, b"")]))
        self.send(encode(BATTERY_READ, [(1, b""), (2, b""), (3, b"")]))

    def frames(self):
        while True:
            start = self.buffer.find(0x5A)
            if start < 0:
                self.buffer.clear()
                return
            del self.buffer[:start]
            if len(self.buffer) < 4:
                return
            total = 3 + int.from_bytes(self.buffer[1:3], "big") + 2
            if len(self.buffer) < total:
                return
            raw = bytes(self.buffer[:total])
            if raw[3] != 0 or crc16_xmodem(raw[:-2]).to_bytes(2, "big") != raw[-2:]:
                del self.buffer[:1]
                continue
            del self.buffer[:total]
            yield raw[4:6], parse_params(raw[6:-2])

    def handle(self, packet):
        command, params = packet
        if command == ANC_READ:
            value = params.get(1, b"")
            if len(value) == 2:
                self.level, self.hw_mode = value[0], value[1]
                mode = BYTE_TO_MODE.get(self.hw_mode)
                if mode == "nc" and self.level == LEVEL_DYNAMIC and "adaptive" in self.features["modes"]:
                    mode = "adaptive"
                self.state["mode"] = mode
                if self.hw_mode == 2 and self.features["voice"]:
                    self.state["voice"] = self.level == VOICE_ON
                self.mark_ready()
        elif command == ANC_CHANGED_LEGACY:
            self.refresh()   # older models only say "it changed"
        elif command in (BATTERY_READ, BATTERY_NOTIFY):
            self._on_battery(params)

    def _on_battery(self, params):
        # Parameter 3 holds one charging byte per part (left, right, case)
        # on earbuds, a single one otherwise: 01 = charging
        flags = params.get(3, b"")
        both = params.get(2, b"")
        if len(both) == 3 and not NO_TWS.search(self.name):
            for i, (part, level) in enumerate(zip(("left", "right", "case"), both)):
                charging = flags[i] == 1 if len(flags) == 3 else b"\x01" in flags
                if level:
                    self.set_battery(part, level, charging)
        elif len(params.get(1, b"")) == 1:
            self.set_battery("single", params[1][0], b"\x01" in flags)

    def _set(self, value):
        self.send(encode(ANC_SET, [(1, bytes(value))]))

    def set_mode(self, mode):
        target = {"off": 0, "nc": 1, "adaptive": 1, "ambient": 2}[mode]
        self._set([target, 0xFF])
        if mode == "adaptive":
            self._set([1, LEVEL_DYNAMIC])
        elif mode == "nc" and self.level == LEVEL_DYNAMIC:
            self._set([1, LEVEL_NORMAL])
        self.state["mode"] = mode
        self.refresh()

    def set_voice(self, enabled):
        self._set([2, VOICE_ON if enabled else VOICE_OFF])
        self.state["voice"] = enabled
        self.refresh()

    def refresh(self):
        self.send(encode(ANC_READ, [(1, b""), (2, b"")]))
