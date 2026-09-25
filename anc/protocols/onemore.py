"""1MORE SonoFlow headphones over RFCOMM.

Written from the byte-level facts documented by Gadgetbridge (no code
copied). The few packets needed are fixed byte strings (their checksums
never change); answers start with 01 01 00 and byte 3 names the command.
"""

from .base import Protocol

SPP = "00001101-0000-1000-8000-00805f9b34fb"
GET_INFO = bytes.fromhex("1101004e0000001c42")
GET_NOISE = bytes.fromhex("1101005f0000000c43")
SET_NOISE = bytes.fromhex("1101005e000100135c")   # + mode byte
REPLY = b"\x01\x01\x00"
CMD_INFO, CMD_NOISE = 0x4E, 0x5F

BYTE_TO_MODE = {0: "off", 1: "nc", 3: "ambient"}
MODE_TO_BYTE = {v: k for k, v in BYTE_TO_MODE.items()}


class OneMore(Protocol):
    transport = ("rfcomm", [SPP], None)
    ready_timeout = 3.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.features["modes"] = ["nc", "ambient", "off"]

    def start(self):
        self.send(GET_NOISE)
        self.send(GET_INFO)

    def frames(self):
        while True:
            start = self.buffer.find(REPLY)
            if start < 0:
                del self.buffer[:max(0, len(self.buffer) - 2)]
                return
            del self.buffer[:start]
            need = 19 if len(self.buffer) > 3 and self.buffer[3] == CMD_INFO else 10
            if len(self.buffer) < need:
                return
            raw = bytes(self.buffer[:need])
            del self.buffer[:need]
            yield raw

    def handle(self, raw):
        if raw[3] == CMD_NOISE and raw[9] in BYTE_TO_MODE:
            self.state["mode"] = BYTE_TO_MODE[raw[9]]
            self.mark_ready()
        elif raw[3] == CMD_INFO:
            self.set_battery("single", raw[13])

    def set_mode(self, mode):
        self.send(SET_NOISE + bytes([MODE_TO_BYTE[mode]]))
        self.state["mode"] = mode

    def refresh(self):
        self.send(GET_NOISE)
