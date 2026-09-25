"""Xiaomi and Redmi Buds over RFCOMM.

Written from the byte-level facts documented by Gadgetbridge (no code
copied). Frame, big-endian:

    FE DC BA | type | opcode | length u16 | [00 when a response] | seq | payload | EF

Types: C4 our request, 04 a response, C0 the buds' request, C7 their
notification. The buds only accept settings after a two-way login: each
side sends a 16-byte challenge and checks the other's SAFER+ answer
(see safer.py).
"""

import os

from . import safer
from .base import Protocol

UUID = "0000fd2d-0000-1000-8000-00805f9b34fb"
HEAD, TAIL = b"\xfe\xdc\xba", 0xEF

PHONE_REQUEST, RESPONSE, BUDS_REQUEST, BUDS_NOTIFY = 0xC4, 0x04, 0xC0, 0xC7
OP_INFO, OP_ANC, OP_RUN_INFO, OP_STATUS = 0x02, 0x08, 0x09, 0x0E
OP_CHALLENGE, OP_CONFIRM, OP_NOTIFY_CONFIG = 0x50, 0x51, 0xF4

BYTE_TO_MODE = {0: "off", 1: "nc", 2: "ambient"}
MODE_TO_BYTE = {v: k for k, v in BYTE_TO_MODE.items()}


def is_request(kind):
    return bool(kind & 0x40)


def encode(kind, opcode, seq, payload=b""):
    response = not is_request(kind)
    length = len(payload) + (2 if response else 1)
    return HEAD + bytes([kind, opcode]) + length.to_bytes(2, "big") \
        + (b"\x00" if response else b"") + bytes([seq & 0xFF]) + bytes(payload) + bytes([TAIL])


def tlv(payload, index_at=1):
    """Records (length, index, value...); yields (index, record bytes)."""
    i = 0
    while i + index_at < len(payload):
        length = payload[i]
        record = payload[i:i + length + 1]
        yield record[index_at], record
        i += length + 1


class Xiaomi(Protocol):
    transport = ("rfcomm", [UUID], None)
    ready_timeout = 6.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.seq = 0
        self.features["modes"] = ["nc", "ambient", "off"]

    def _request(self, opcode, payload):
        self.send(encode(PHONE_REQUEST, opcode, self.seq, payload))
        self.seq = (self.seq + 1) & 0xFF

    def start(self):
        self._request(OP_CHALLENGE, b"\x01" + os.urandom(16))

    def frames(self):
        while True:
            start = self.buffer.find(HEAD)
            if start < 0:
                del self.buffer[:max(0, len(self.buffer) - 2)]
                return
            del self.buffer[:start]
            if len(self.buffer) < 8:
                return
            kind, opcode = self.buffer[3], self.buffer[4]
            length = int.from_bytes(self.buffer[5:7], "big")
            total = 7 + length + 1
            if len(self.buffer) < total:
                return
            raw = bytes(self.buffer[:total])
            del self.buffer[:total]
            if raw[-1] != TAIL:
                continue
            body = raw[7:-1]
            if not is_request(kind):
                body = body[1:]          # the status byte of a response
            yield kind, opcode, body[0] if body else 0, body[1:]

    def handle(self, packet):
        kind, opcode, seq, p = packet
        if opcode == OP_CHALLENGE:
            if kind == RESPONSE:
                self._request(OP_CONFIRM, b"\x01\x00")      # our challenge was answered
            elif len(p) >= 17:
                self.send(encode(RESPONSE, OP_CHALLENGE, seq, b"\x01" + safer.respond(p[1:17])))
        elif opcode == OP_CONFIRM and kind == BUDS_REQUEST:
            # Logged in: ask for battery (info) and the current mode (run info)
            self.send(encode(RESPONSE, OP_CONFIRM, seq, b"\x01"))
            self._request(OP_INFO, b"\xff\xff\xff\xff")
            self._request(OP_RUN_INFO, b"\xff\xff\xff\xff")
        elif opcode == OP_INFO and kind == RESPONSE:
            for index, record in tlv(p):
                if index == 0x07 and len(record) >= 5:
                    self._battery(record[2:5])
        elif opcode == OP_RUN_INFO and kind == RESPONSE:
            for index, record in tlv(p):
                if index == 0x09 and len(record) >= 3:
                    self._mode(record[2])
        elif opcode == OP_STATUS and kind == BUDS_REQUEST:
            for index, record in tlv(p):
                if index == 0x00 and len(record) >= 5:
                    self._battery(record[2:5])
                elif index == 0x04 and len(record) >= 3:
                    self._mode(record[2])
            self.send(encode(RESPONSE, OP_STATUS, seq))
        elif opcode == OP_NOTIFY_CONFIG and kind == BUDS_NOTIFY:
            for index, record in tlv(p, index_at=2):
                if index == 0x0B and len(record) >= 4:
                    self._mode(record[3])
            self.send(encode(RESPONSE, OP_NOTIFY_CONFIG, seq))

    def _mode(self, value):
        if value in BYTE_TO_MODE:
            self.state["mode"] = BYTE_TO_MODE[value]
            self.mark_ready()

    def _battery(self, values):
        # left, right, case; & 0x7F = %, 0x80 = charging, FF = absent
        for part, v in zip(("left", "right", "case"), values):
            if v != 0xFF:
                self.set_battery(part, v & 0x7F, v & 0x80)

    def set_mode(self, mode):
        self._request(OP_ANC, bytes([0x02, 0x04, MODE_TO_BYTE[mode]]))
        self.state["mode"] = mode

    def refresh(self):
        if self.ready:
            self._request(OP_RUN_INFO, b"\xff\xff\xff\xff")
