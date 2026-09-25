"""Samsung Galaxy Buds over RFCOMM.

Written from the byte-level facts documented by GalaxyBudsClient and
Gadgetbridge (no code copied). Frame:

    SOM | header u16 LE | id | payload | CRC16 u16 LE | EOM

header bits 0-9 = size (id + payload + CRC); the CRC is CRC-16/XMODEM over
id + payload. Buds+ and later use FD/DD; the first Galaxy Buds (2019) use
FE/EE with a 1-byte type then a 1-byte size instead of the header.

There is no "get": the buds push their full state (0x61) after connecting
and whenever something changes; battery comes in 0x60 updates.
"""

import re

from .base import Protocol
from .checksums import crc16_xmodem

UUIDS = ["2e73a4ad-332d-41fc-90e2-16bef06523f2",   # Buds2 and later
         "00001101-0000-1000-8000-00805f9b34fb",   # Buds+, Live, Pro (SPP)
         "00001102-0000-1000-8000-00805f9b34fd"]   # Galaxy Buds (2019)

STATUS, EXTENDED_STATUS = 0x60, 0x61
NOISE_UPDATE, NOISE_CONTROLS = 0x77, 0x78
DETECT_CONVERSATIONS = 0x7A
AMBIENT_ON, AMBIENT_UPDATE = 0x80, 0x81
AMBIENT_VOLUME = 0x84
MANAGER_INFO = 0x88
ANC_ON, ANC_UPDATE = 0x98, 0x9B

MODE_TO_BYTE = {"off": 0, "nc": 1, "ambient": 2}
BYTE_TO_MODE = {v: k for k, v in MODE_TO_BYTE.items()}


def generation(name):
    """'legacy' (2019), 'plus', 'live', or 'modern' (Pro and everything after)."""
    if re.search(r"Galaxy Buds \(", name):
        return "legacy"
    if re.search(r"Buds\+", name):
        return "plus"
    if re.search(r"Buds Live", name):
        return "live"
    return "modern"


class Samsung(Protocol):
    transport = ("rfcomm", UUIDS, None)
    ready_timeout = 4.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.gen = generation(name)
        self.legacy = self.gen == "legacy"
        self.greeted = False
        modes = {"legacy": ["ambient", "off"], "plus": ["ambient", "off"],
                 "live": ["nc", "off"], "modern": ["nc", "ambient", "off"]}[self.gen]
        self.features["modes"] = modes
        # Ambient volume steps (Buds (2019): 4; Buds Pro: 3; others: 2)
        if self.gen != "live":
            self.features["ambientMax"] = 4 if self.legacy else 3 if re.search(r"Buds Pro\b", name) else 2
        # Conversation detection: Buds Pro, Buds2 Pro, Buds3 Pro
        self.features["chat"] = bool(re.search(r"Buds[23]? ?Pro", name))

    def encode(self, ident, payload=b""):
        body = bytes([ident]) + bytes(payload)
        size = len(body) + 2
        crc = crc16_xmodem(body).to_bytes(2, "little")
        if self.legacy:
            return bytes([0xFE, 0x00, size]) + body + crc + b"\xee"
        return bytes([0xFD]) + size.to_bytes(2, "little") + body + crc + b"\xdd"

    def start(self):
        pass   # the buds speak first

    def frames(self):
        som, eom, head = (0xFE, 0xEE, 3) if self.legacy else (0xFD, 0xDD, 3)
        while True:
            start = self.buffer.find(som)
            if start < 0:
                self.buffer.clear()
                return
            del self.buffer[:start]
            if len(self.buffer) < head:
                return
            size = self.buffer[2] if self.legacy else int.from_bytes(self.buffer[1:3], "little") & 0x3FF
            total = head + size + 1
            if len(self.buffer) < total:
                return
            frame = bytes(self.buffer[:total])
            body, crc = frame[head:head + size - 2], frame[head + size - 2:head + size]
            if frame[-1] != eom or size < 3 or crc16_xmodem(body).to_bytes(2, "little") != crc:
                del self.buffer[:1]
                continue
            del self.buffer[:total]
            yield body[0], body[1:]

    def handle(self, frame):
        ident, p = frame
        if ident == EXTENDED_STATUS:
            self._on_extended(p)
        elif ident == STATUS:
            self._on_status(p)
        elif ident == NOISE_UPDATE and p:
            self.state["mode"] = BYTE_TO_MODE.get(p[0], self.state["mode"])
        elif ident == AMBIENT_UPDATE and p:
            self.state["mode"] = "ambient" if p[0] else "off"
        elif ident == ANC_UPDATE and p:
            self.state["mode"] = "nc" if p[0] else "off"

    def _on_extended(self, p):
        if len(p) < 6:
            return
        self._battery(p[2], p[3], p[7] if self.gen != "legacy" and len(p) > 7 else -1)
        if self.gen == "legacy" and len(p) > 9:
            self.state["mode"] = "ambient" if p[7] else "off"
            self.state["ambient"] = p[9]
        elif self.gen == "plus" and len(p) > 9:
            self.state["mode"] = "ambient" if p[8] else "off"
            self.state["ambient"] = p[9]
        elif self.gen == "live" and len(p) > 12:
            self.state["mode"] = "nc" if p[12] else "off"
        elif len(p) > 12:
            self.state["mode"] = BYTE_TO_MODE.get(p[12])
            if len(p) > 23:
                self.state["ambient"] = min(p[23], self.features["ambientMax"])
            if self.features["chat"] and len(p) > 26:
                self.state["chat"] = bool(p[26])
        if not self.greeted:
            # Introduce ourselves like the official app does (client "other")
            self.greeted = True
            self.send(self.encode(MANAGER_INFO, b"\x01\x02\x22"))
        self.mark_ready()

    def _on_status(self, p):
        if self.legacy and len(p) > 2:
            self._battery(p[1], p[2], -1)
        elif len(p) > 6:
            charging = p[7] if len(p) > 7 else 0
            self._battery(p[1], p[2], p[6], charging)

    def _battery(self, left, right, case, charging=0):
        # Samsung reports 0 for a bud that is not connected
        if left:
            self.set_battery("left", left, charging & 0x10)
        if right:
            self.set_battery("right", right, charging & 0x04)
        if case > 0:
            self.set_battery("case", case, charging & 0x01)

    def set_mode(self, mode):
        if self.gen in ("legacy", "plus"):
            self.send(self.encode(AMBIENT_ON, bytes([mode == "ambient"])))
        elif self.gen == "live":
            self.send(self.encode(ANC_ON, bytes([mode == "nc"])))
        else:
            self.send(self.encode(NOISE_CONTROLS, bytes([MODE_TO_BYTE[mode]])))
        self.state["mode"] = mode

    def set_ambient(self, level):
        self.send(self.encode(AMBIENT_VOLUME, bytes([level])))
        self.state["ambient"] = level

    def set_chat(self, enabled):
        self.send(self.encode(DETECT_CONVERSATIONS, bytes([enabled])))
        self.state["chat"] = enabled

    def refresh(self):
        pass   # state is pushed; a reconnect gets a fresh 0x61
