"""Nothing and CMF earbuds/headphones: the "Nothing X" protocol over RFCOMM.

Written from the byte-level facts documented by Gadgetbridge, EarA-linux,
earctl and cmfctl (no code copied). Frame, little-endian:

    55 | control u16 | command u16 | length u16 | seq | payload | CRC16

The CRC (CRC-16/MODBUS, over everything before it) is present when bit
0x20 of the control word is set. Requests are 0xC0xx (get) and 0xF0xx
(set); answers clear bit 0x8000 (0xC01E -> 0x401E); notifications from
the device are 0xE0xx.
"""

import re

from .base import Protocol
from .checksums import crc16_modbus

UUID = "aeac4a03-dff5-498f-843a-34487cf133eb"

GET_ANC, SET_ANC, GET_BATTERY = 0xC01E, 0xF00F, 0xC007
ANC_REPLIES = (0x401E, 0xE003)
BATTERY_REPLIES = (0x4007, 0xE001)

# Mode byte -> common mode (1-3 are cancelling strengths: high, mid, low)
BYTE_TO_MODE = {1: "nc", 2: "nc", 3: "nc", 4: "adaptive", 5: "off", 7: "ambient"}
BATTERY_PART = {0x02: "left", 0x03: "right", 0x04: "case", 0x06: "single"}

# Models with an adaptive mode, and models without noise control at all
ADAPTIVE = re.compile(r"ear \(a\)|ear \(3\)|cmf buds 2 plus|headphone", re.I)
NO_ANC = re.compile(r"ear \(stick\)|ear \(open\)", re.I)

# The CMF Headphone Pro ignores the level when leaving "off": resend once
RESEND_AFTER = 0.5


def encode(command, payload, seq):
    raw = bytes([0x55]) + (0x0160).to_bytes(2, "little") + command.to_bytes(2, "little") \
        + len(payload).to_bytes(2, "little") + bytes([seq & 0xFF]) + bytes(payload)
    return raw + crc16_modbus(raw).to_bytes(2, "little")


class Nothing(Protocol):
    transport = ("rfcomm", [UUID], [15, 28])
    ready_timeout = 3.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.seq = 0
        self.nc_byte = 1          # last cancelling strength seen
        self.wanted = None        # mode byte we asked for, until confirmed
        self.resend_at = None     # when to send it once more (quirk above)
        modes = [] if NO_ANC.search(name) else ["nc", "ambient", "off"]
        if modes and ADAPTIVE.search(name):
            modes.insert(1, "adaptive")
        self.features["modes"] = modes

    def _request(self, command, payload=b""):
        self.send(encode(command, payload, self.seq))
        self.seq = (self.seq + 1) % 0xFD

    def start(self):
        self._request(GET_BATTERY)
        if self.features["modes"]:
            self._request(GET_ANC)

    def frames(self):
        while True:
            start = self.buffer.find(0x55)
            if start < 0:
                self.buffer.clear()
                return
            del self.buffer[:start]
            if len(self.buffer) < 8:
                return
            control = int.from_bytes(self.buffer[1:3], "little")
            length = int.from_bytes(self.buffer[5:7], "little")
            total = 8 + length + (2 if control & 0x20 else 0)
            if len(self.buffer) < total:
                return
            frame = bytes(self.buffer[:total])
            if control & 0x20 and crc16_modbus(frame[:-2]) != int.from_bytes(frame[-2:], "little"):
                del self.buffer[:1]   # not a real frame start: resync
                continue
            del self.buffer[:total]
            yield int.from_bytes(frame[3:5], "little"), frame[8:8 + length]

    def handle(self, frame):
        command, payload = frame
        if command in ANC_REPLIES:
            self._on_anc(payload)
        elif command in BATTERY_REPLIES:
            self._on_battery(payload)

    def _on_anc(self, payload):
        # 3-byte records (type, value, 0); type 1 is the current mode
        for i in range(0, len(payload) - 1, 3):
            if payload[i] == 0x01:
                value = payload[i + 1]
                if value in (1, 2, 3):
                    self.nc_byte = value
                if self.wanted is not None and value != self.wanted:
                    self.resend_at = -1   # tick() schedules one more try
                    return
                self.wanted = None
                self.state["mode"] = BYTE_TO_MODE.get(value, self.state["mode"])
                self.mark_ready()
                return

    def _on_battery(self, payload):
        count = payload[0] if payload else 0
        for i in range(count):
            record = payload[1 + i * 2:3 + i * 2]
            if len(record) == 2 and record[0] in BATTERY_PART:
                self.set_battery(BATTERY_PART[record[0]], record[1] & 0x7F, record[1] & 0x80)

    def set_mode(self, mode):
        value = {"nc": self.nc_byte, "adaptive": 4, "off": 5, "ambient": 7}[mode]
        self._request(SET_ANC, bytes([0x01, value, 0x00]))
        self.wanted = value
        self.state["mode"] = mode

    def wants_tick(self):
        return self.resend_at is not None

    def tick(self, now):
        super().tick(now)
        if self.resend_at == -1:
            self.resend_at = now + RESEND_AFTER
        elif self.resend_at is not None and now >= self.resend_at:
            self._request(SET_ANC, bytes([0x01, self.wanted, 0x00]))
            self.resend_at = None
            self.wanted = None   # accept whatever the headset reports next

    def refresh(self):
        if self.features["modes"]:
            self._request(GET_ANC)
