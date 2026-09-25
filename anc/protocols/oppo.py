"""Oppo, OnePlus and realme earbuds (the "HeyMelody" protocol) over RFCOMM.

Written from the byte-level facts documented by Gadgetbridge (no code
copied). Frame, little-endian, no checksum:

    AA | length (total - 2) | 00 00 | command u16 | seq | payload length u16 | payload

Noise control is only known on some models, so it is probed: without an
answer the session shows the battery alone.
"""

from .base import Protocol

UUID = "0000079a-d102-11e1-9b23-00025b00a5a5"

BATTERY_REQ, BATTERY_RET = 0x0106, 0x8106
SUBSCRIBE, NOTIFY = 0x0205, 0x0204
ANC_SET, ANC_REQ, ANC_RET = 0x0404, 0x010C, 0x810C

SUB_BATTERY, SUB_ANC = 0x01, 0x03
BYTE_TO_MODE = {0x01: "off", 0x02: "ambient", 0x08: "nc"}
MODE_TO_BYTE = {v: k for k, v in BYTE_TO_MODE.items()}
BATTERY_PART = {1: "left", 2: "right", 3: "case"}


class Oppo(Protocol):
    transport = ("rfcomm", [UUID], None)
    ready_timeout = 3.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.seq = 0

    def _request(self, command, payload=b""):
        body = b"\x00\x00" + command.to_bytes(2, "little") + bytes([self.seq & 0xFF]) \
            + len(payload).to_bytes(2, "little") + bytes(payload)
        self.seq += 1
        self.send(bytes([0xAA, len(body)]) + body)

    def start(self):
        self._request(ANC_REQ, b"\x01\x01")
        self._request(SUBSCRIBE, bytes([0x09, SUB_BATTERY, SUB_ANC]))
        self._request(BATTERY_REQ)

    def frames(self):
        while True:
            start = self.buffer.find(0xAA)
            if start < 0:
                self.buffer.clear()
                return
            del self.buffer[:start]
            if len(self.buffer) < 2 or len(self.buffer) < self.buffer[1] + 2:
                return
            raw = bytes(self.buffer[:self.buffer[1] + 2])
            del self.buffer[:len(raw)]
            if len(raw) < 9:
                continue
            length = int.from_bytes(raw[7:9], "little")
            yield int.from_bytes(raw[4:6], "little"), raw[9:9 + length]

    def handle(self, packet):
        command, p = packet
        if command == ANC_RET and len(p) >= 4 and p[0] == 0 and p[1] == 0x01:
            self._on_mode(p[3])
        elif command == NOTIFY and p:
            if p[0] == SUB_ANC and len(p) >= 3:
                self._on_mode(p[2])
            elif p[0] == SUB_BATTERY:
                self._on_battery(p)
        elif command == BATTERY_RET and p and p[0] == 0:
            self._on_battery(p)

    def _on_mode(self, value):
        if value in BYTE_TO_MODE:
            self.features["modes"] = ["nc", "ambient", "off"]
            self.state["mode"] = BYTE_TO_MODE[value]
            self.mark_ready()

    def _on_battery(self, p):
        # [status or type, count, (part, value)...]; value & 0x7F = %, 0x80 = charging
        for i in range(2, len(p) - 1, 2):
            part = BATTERY_PART.get(p[i])
            if part and p[i + 1] != 0xFF and not (part == "case" and p[i + 1] & 0x7F == 0):
                self.set_battery(part, p[i + 1] & 0x7F, p[i + 1] & 0x80)

    def set_mode(self, mode):
        self._request(ANC_SET, bytes([0x01, 0x01, MODE_TO_BYTE[mode]]))
        self.state["mode"] = mode

    def refresh(self):
        self._request(ANC_REQ, b"\x01\x01")
