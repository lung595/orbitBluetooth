"""Bose headphones: BMAP over RFCOMM.

Written from the byte-level facts documented by Gadgetbridge, based-connect
and bosectl (no code copied). Frame, no start byte and no checksum:

    function block | function | operator | payload length | payload

Operators: 0 set, 1 get, 2 set-get, 3 status, 4 error, 5 start, 6 result.
Three noise-control families:
- QC35 / QC35 II: "ANR" [1.6], levels off / high / wind / low;
- NC700: "CNC" [1.5], a 0-10 level (sent three times: enabling resets it);
- QC45, QC Ultra, QC Headphones: "audio modes" [31.3], preset 0 = Quiet,
  1 = Aware ([1.5] needs the cloud account on these, so it is not used).
"""

import re

from .base import Protocol

UUIDS = ["00000000-deca-fade-deca-deafdecacaff",   # BMAP
         "00001101-0000-1000-8000-00805f9b34fb"]   # SPP
# CSR chips (QC35, QC45) listen on 8, QCC chips (QC Ultra 2nd gen) on 2
CHANNELS = [8, 2]

SET, GET, SETGET, STATUS, ERROR, START, RESULT = 0, 1, 2, 3, 4, 5, 6

ANR, CNC, MODES, BATTERY = (1, 6), (1, 5), (31, 3), (2, 2)


def family(name):
    if re.search(r"QC ?35|QuietComfort 35", name, re.I):
        return "anr"
    if re.search(r"NC ?700|Headphones 700", name, re.I):
        return "cnc"
    return "modes"


def frame(block, function, operator, payload=b""):
    return bytes([block, function, operator, len(payload)]) + bytes(payload)


class Bose(Protocol):
    transport = ("rfcomm", UUIDS, CHANNELS)
    ready_timeout = 4.0

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.kind = family(name)
        # NC700 has no "off": "ambient" is the lowest cancelling level
        self.features["modes"] = {"anr": ["nc", "off"], "cnc": ["nc", "ambient"],
                                  "modes": ["nc", "ambient"]}[self.kind]

    def start(self):
        self.send(frame(0, 1, GET))                            # BMAP version: required first
        self.send(frame(9, 2, SETGET, b"\x01\x37"))            # push status changes (blocks 0,1,2,4,5)
        self.send(frame(9, 2, SETGET, b"\x01\x37\x00\x00\x80"))  # ... and block 31
        self.refresh()
        self.send(frame(*BATTERY, GET))

    def frames(self):
        while len(self.buffer) >= 4:
            total = 4 + self.buffer[3]
            if len(self.buffer) < total:
                return
            raw = bytes(self.buffer[:total])
            del self.buffer[:total]
            yield (raw[0], raw[1]), raw[2] & 0x0F, raw[4:]

    def handle(self, packet):
        function, op, p = packet
        if op == ERROR:
            if function in (ANR, CNC, MODES):
                # This model does not take the command: battery only
                self.features["modes"] = []
                self.mark_ready()
            return
        if op not in (STATUS, RESULT) or not p:
            return
        if function == ANR:
            self.state["mode"] = "off" if p[0] == 0 else "nc"
            self.mark_ready()
        elif function == CNC and len(p) >= 2:
            level = 10 - p[1]
            self.state["mode"] = "nc" if level >= 5 else "ambient"
            self.mark_ready()
        elif function == MODES:
            self.state["mode"] = {0: "nc", 1: "ambient"}.get(p[0])   # others: custom presets
            self.mark_ready()
        elif function == BATTERY:
            self.set_battery("single", p[0])

    def set_mode(self, mode):
        if self.kind == "anr":
            self.send(frame(*ANR, SET, bytes([1 if mode == "nc" else 0])))
        elif self.kind == "cnc":
            payload = bytes([10 - (10 if mode == "nc" else 0), 1])
            for _ in range(3):
                self.send(frame(*CNC, SET, payload))
        else:
            self.send(frame(*MODES, START, bytes([0 if mode == "nc" else 1, 0])))
        self.state["mode"] = mode

    def refresh(self):
        self.send(frame(*{"anr": ANR, "cnc": CNC, "modes": MODES}[self.kind], GET))
