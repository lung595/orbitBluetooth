"""EarFun earbuds (Air Pro 4, Air S, Free Pro 3): GAIA packets over RFCOMM.

Written from the byte-level facts documented by Gadgetbridge (no code
copied). Frame, big-endian, no checksum:

    FF | version 04 | flags 00 | payload length | vendor u16 (000A) | command u16 | payload

Answers carry the command with bit 0x8000 set; their payload is
(status, value). The same "get" commands also arrive on their own when
the mode is changed on the earbuds.
"""

from .base import Protocol

SPP = "00001101-0000-1000-8000-00805f9b34fb"
VENDOR = 0x000A

SET_MODE, GET_MODE = 0x0314, 0x0315
SET_ANC_KIND, GET_ANC_KIND = 0x033A, 0x033B
BATTERY = {0x0306: "left", 0x0307: "right", 0x0317: "case"}

BYTE_TO_MODE = {0: "off", 1: "nc", 2: "ambient"}
MODE_TO_BYTE = {v: k for k, v in BYTE_TO_MODE.items()}
# Cancelling kinds: 2 strong, 3 balanced, 4 adaptive (environment), 0 adaptive (ear), 1 wind
ADAPTIVE_KINDS = (0, 4)
STRONG = 2


def encode(command, payload=b""):
    return bytes([0xFF, 0x04, 0x00, len(payload)]) + VENDOR.to_bytes(2, "big") \
        + command.to_bytes(2, "big") + bytes(payload)


class EarFun(Protocol):
    transport = ("rfcomm", [SPP], None)
    ready_timeout = 3.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.kind = None      # cancelling kind, once the earbuds told us
        self.features["modes"] = ["nc", "ambient", "off"]

    def start(self):
        self.send(encode(GET_MODE))
        self.send(encode(GET_ANC_KIND))
        for command in BATTERY:
            self.send(encode(command))

    def frames(self):
        while True:
            start = self.buffer.find(0xFF)
            if start < 0:
                self.buffer.clear()
                return
            del self.buffer[:start]
            if len(self.buffer) < 8:
                return
            if self.buffer[1] not in (0x03, 0x04):
                del self.buffer[:1]
                continue
            total = 8 + self.buffer[3]
            if len(self.buffer) < total:
                return
            raw = bytes(self.buffer[:total])
            del self.buffer[:total]
            yield int.from_bytes(raw[6:8], "big") & 0x7FFF, raw[8:]

    def handle(self, packet):
        command, p = packet
        if len(p) < 2:
            return
        value = p[1]
        if command == GET_MODE and value in BYTE_TO_MODE:
            self.state["mode"] = BYTE_TO_MODE[value]
            self._adaptive_view()
            self.mark_ready()
        elif command == GET_ANC_KIND:
            self.kind = value
            if "adaptive" not in self.features["modes"]:
                self.features["modes"] = ["nc", "adaptive", "ambient", "off"]
            self._adaptive_view()
        elif command in BATTERY and value > 0:
            self.set_battery(BATTERY[command], value)

    def _adaptive_view(self):
        if self.state["mode"] == "nc" and self.kind in ADAPTIVE_KINDS:
            self.state["mode"] = "adaptive"

    def set_mode(self, mode):
        self.send(encode(SET_MODE, bytes([MODE_TO_BYTE["nc" if mode == "adaptive" else mode]])))
        if mode == "adaptive":
            self.send(encode(SET_ANC_KIND, bytes([4])))
            self.kind = 4
        elif mode == "nc" and self.kind in ADAPTIVE_KINDS:
            self.send(encode(SET_ANC_KIND, bytes([STRONG])))
            self.kind = STRONG
        self.state["mode"] = mode

    def refresh(self):
        self.send(encode(GET_MODE))
