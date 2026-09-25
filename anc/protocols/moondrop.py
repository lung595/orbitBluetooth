"""Moondrop Space Travel 2 (and 2 Ultra): GAIA v3 packets over RFCOMM.

Written from the byte-level facts documented by Gadgetbridge (no code
copied). Frame, big-endian, no checksum:

    FF 04 00 | payload length | vendor u16 (001D) | command u16 | payload

command = feature << 9 | type << 7 | pdu, type 0 command, 1 notification,
2 response, 3 error. Noise control is the "audio curation" feature (8):
pdu 3 reads the mode as an index (0 normal, 1 cancelling, 2 transparency),
pdu 4 sets it as a mask (1, 2, 4).
"""

from .base import Protocol

GAIA = "00001107-d102-11e1-9b23-00025b00a5a5"
SPP = "00001101-0000-1000-8000-00805f9b34fb"
VENDOR = 0x001D
CURATION, GET_MODE, SET_MODE = 0x08, 0x03, 0x04
COMMAND, NOTIFICATION, RESPONSE, ERROR = 0, 1, 2, 3

INDEX_TO_MODE = {0: "off", 1: "nc", 2: "ambient"}
MODE_TO_MASK = {"off": 1, "nc": 2, "ambient": 4}


def encode(feature, pdu, payload=b""):
    command = (feature << 9) | (COMMAND << 7) | pdu
    return bytes([0xFF, 0x04, 0x00, len(payload)]) + VENDOR.to_bytes(2, "big") \
        + command.to_bytes(2, "big") + bytes(payload)


class Moondrop(Protocol):
    transport = ("rfcomm", [GAIA, SPP], None)
    ready_timeout = 3.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.features["modes"] = ["nc", "ambient", "off"]

    def start(self):
        self.send(encode(CURATION, GET_MODE))

    def frames(self):
        while True:
            start = self.buffer.find(0xFF)
            if start < 0:
                self.buffer.clear()
                return
            del self.buffer[:start]
            if len(self.buffer) < 8:
                return
            total = 8 + self.buffer[3]
            if len(self.buffer) < total:
                return
            raw = bytes(self.buffer[:total])
            del self.buffer[:total]
            command = int.from_bytes(raw[6:8], "big")
            yield command >> 9, (command >> 7) & 0x03, command & 0x7F, raw[8:]

    def handle(self, packet):
        feature, kind, pdu, p = packet
        if feature != CURATION:
            return
        if kind == ERROR:
            self.features["modes"] = []
            self.mark_ready()
        elif pdu == GET_MODE and kind in (RESPONSE, NOTIFICATION) and p and p[0] in INDEX_TO_MODE:
            self.state["mode"] = INDEX_TO_MODE[p[0]]
            self.mark_ready()
        elif pdu == SET_MODE and kind == RESPONSE:
            self.refresh()

    def set_mode(self, mode):
        self.send(encode(CURATION, SET_MODE, bytes([MODE_TO_MASK[mode]])))
        self.state["mode"] = mode

    def refresh(self):
        self.send(encode(CURATION, GET_MODE))
