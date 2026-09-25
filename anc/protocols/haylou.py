"""Haylou S35 ANC over RFCOMM.

Written from the byte-level facts documented by Gadgetbridge (no code
copied). Frame: AA BB CC C0 | payload | DD EE FF. The handshake answer
carries the battery level; the headphones cannot be asked for their
noise-control mode, so it stays unknown until Orbit sets one.
"""

from .base import Protocol

SPP = "00001101-0000-1000-8000-00805f9b34fb"
HEAD, TAIL = bytes.fromhex("aabbccc0"), bytes.fromhex("ddeeff")
HANDSHAKE = bytes.fromhex("020005000000000f")
MODE_TO_BYTE = {"off": 0, "nc": 1, "ambient": 2}


def encode(payload):
    return HEAD + bytes(payload) + TAIL


class Haylou(Protocol):
    transport = ("rfcomm", [SPP], None)
    ready_timeout = 2.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.features["modes"] = ["nc", "ambient", "off"]

    def start(self):
        self.send(encode(HANDSHAKE))

    def frames(self):
        while True:
            start = self.buffer.find(HEAD)
            end = self.buffer.find(TAIL, start + len(HEAD)) if start >= 0 else -1
            if start < 0 or end < 0:
                return
            raw = bytes(self.buffer[start:end + len(TAIL)])
            del self.buffer[:end + len(TAIL)]
            yield raw

    def handle(self, raw):
        # length u16 BE at 5-6, payload from 7; the battery is payload[3]
        if len(raw) >= 11:
            length = int.from_bytes(raw[5:7], "big")
            payload = raw[7:7 + length]
            if len(payload) > 3:
                self.set_battery("single", payload[3])
        self.mark_ready()

    def set_mode(self, mode):
        self.send(encode(bytes([0x08, 0x00, 0x04, 0x00, 0x02, 0x04, MODE_TO_BYTE[mode]])))
        self.state["mode"] = mode
