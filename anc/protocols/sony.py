"""Sony headphones: the "MDR" protocol over RFCOMM (v1 and v2).

The framing lives in sony_frame.py. v1 (WH-1000XM3/XM4, WF-1000XM3...) and v2
(WH-1000XM5/XM6, WF-1000XM4/XM5, LinkBuds, ULT...) share it but not every
payload. Every data frame from the headset must be acknowledged, and we keep
only one command in flight until the headset acknowledges it. On v2 the list
of supported functions tells which noise-control layout the model expects.
Wearing detection (table 2) is in sony_extras.py.
"""

from .base import Protocol
from .sony_extras import SonyExtras
from .sony_frame import END, START, T_ACK, T_DATA, T_DATA2, decode, encode

UUID_V2 = "956c7b26-d49a-4ba8-b03f-b17d393cb6e2"
UUID_V1 = "96cc203e-5068-46ad-b32d-e316f5e069ba"

# How long to wait for an acknowledgement before sending again
RETRY_SECONDS = 1.25
MAX_TRIES = 3

# v2 support-function codes -> what they unlock
FN_NC_TYPE = {0x6D: 0x19, 0x6B: 0x17, 0x68: 0x15, 0x67: 0x22}
FN_BATTERY = {0x20: 0x00, 0x28: 0x08}
FN_BATTERY_DUAL = {0x21: 0x01, 0x29: 0x09}
FN_BATTERY_CASE = {0x22: 0x02, 0x2A: 0x0A}
FN_SPEAK_TO_CHAT = 0xFC

AMBIENT_MAX = 20


class Sony(SonyExtras, Protocol):
    transport = ("rfcomm", [UUID_V2, UUID_V1], None)

    def __init__(self, send, name=""):
        super().__init__(send, name)
        self.version = 0          # 1 or 2 once the headset answered the init
        self.seq = 0              # our sequence number, flipped by each ACK
        self.queue = []           # (table, payload) waiting for the one in flight
        self.inflight = None      # (table, payload, sent at, tries)
        self.nc_type = None       # v2 layout byte (0x19, 0x17, 0x15, 0x22), 0x02 on v1
        self.nc_candidates = []   # v2 layouts still to try when the list is silent
        self.wind = False         # v1 models with a wind-reduction setting
        self.auto = 0             # XM6 automatic ambient (0x19 only)
        self.sensitivity = 0
        self.level = 10           # ambient level, kept while in other modes
        self.voice = False
        self.init_extras()

    # --- transport ---------------------------------------------------------

    def start(self):
        self._queue(b"\x00\x00")  # protocol info: tells v1 from v2

    def _queue(self, payload, table=T_DATA):
        self.queue.append((table, bytes(payload)))
        self._pump()

    def _pump(self, now=None):
        if self.inflight is None and self.queue:
            table, payload = self.queue.pop(0)
            self.send(encode(table, self.seq, payload))
            self.inflight = (table, payload, now, 1)
        self.awaiting = len(self.queue) + (1 if self.inflight else 0)

    def wants_tick(self):
        return self.inflight is not None

    def tick(self, now):
        if not self.inflight:
            return
        table, payload, sent, tries = self.inflight
        if sent is None:
            self.inflight = (table, payload, now, tries)
        elif now - sent > RETRY_SECONDS:
            if tries >= MAX_TRIES:
                # Unanswered: move on (unknown command on this model)
                self.inflight = None
                self._on_silence(payload)
            else:
                self.send(encode(table, self.seq, payload))
                self.inflight = (table, payload, now, tries + 1)
        self._pump(now)

    def frames(self):
        while True:
            start = self.buffer.find(bytes([START]))
            if start < 0:
                self.buffer.clear()
                return
            end = self.buffer.find(bytes([END]), start)
            if end < 0:
                del self.buffer[:start]
                return
            chunk = bytes(self.buffer[start + 1:end])
            del self.buffer[:end + 1]
            frame = decode(chunk)
            if frame:
                yield frame

    def handle(self, frame):
        dtype, seq, payload = frame
        if dtype == T_ACK:
            if self.inflight and seq != self.seq:
                self.seq = seq
                self.inflight = None
                self._pump()
            return
        # Acknowledge every data frame, replies and notifications alike
        self.send(encode(T_ACK, 1 - seq, b""))
        if dtype == T_DATA and payload:
            self._data(payload)
        elif dtype == T_DATA2 and payload:
            self.data2(payload)
        self._pump()

    # --- replies and notifications -------------------------------------------

    def _data(self, p):
        op = p[0]
        if op == 0x01:
            self._on_protocol_info(p)
        elif op == 0x07 and self.version == 2:
            self._on_functions(p)
        elif op in (0x67, 0x69):
            self._on_noise(p, reply=op == 0x67)
        elif op in (0x23, 0x25) and self.version == 2 or op in (0x11, 0x13) and self.version == 1:
            self._on_battery(p)
        elif op in (0xF7, 0xF9):
            self._on_speak_to_chat(p)
        elif op == 0xC9:
            self.on_unit_log(p)

    def _on_protocol_info(self, p):
        if self.version:
            return
        self.version = 2 if len(p) >= 8 else 1
        # Byte 7 says whether the headset also speaks the second table
        self.table2 = self.version == 2 and p[7] == 0x00
        if self.version == 2:
            self._queue(b"\x06\x00")  # which functions this model supports
        else:
            self.nc_type = 0x02
            self.features["chat"] = True
            for payload in (b"\x66\x02", b"\x10\x00", b"\xf6\x05"):
                self._queue(payload)

    def _on_functions(self, p):
        codes = set(p[3:3 + 2 * p[2]:2]) if len(p) > 2 else set()
        types = [FN_NC_TYPE[c] for c in FN_NC_TYPE if c in codes]
        # Unknown list: probe the layouts from newest to oldest
        self.nc_candidates = types[:1] or [0x19, 0x17, 0x15]
        self._probe_noise()
        batteries = [FN_BATTERY[c] for c in FN_BATTERY if c in codes] or [0x00]
        batteries += [FN_BATTERY_DUAL[c] for c in FN_BATTERY_DUAL if c in codes][:1]
        batteries += [FN_BATTERY_CASE[c] for c in FN_BATTERY_CASE if c in codes][:1]
        if 0x21 in codes or 0x29 in codes:
            batteries.remove(batteries[0])  # earbuds report left/right, not a single level
        for kind in batteries:
            self._queue(bytes([0x22, kind]))
        if FN_SPEAK_TO_CHAT in codes:
            self.features["chat"] = True
            self._queue(b"\xf6\x0c")
        self.on_functions(codes)

    def _probe_noise(self):
        if self.nc_candidates:
            self._queue(bytes([0x66, self.nc_candidates.pop(0)]))

    def _on_silence(self, payload):
        # A noise-control query the model ignored: try the next layout
        if payload[0] == 0x66 and self.version == 2 and not self.nc_type:
            if self.nc_candidates:
                self._probe_noise()
            else:
                self.mark_ready()  # no noise control at all

    def _on_noise(self, p, reply=False):
        kind, v = p[1], p[2:]
        if self.version == 1 and kind == 0x02 and len(v) >= 6:
            effect, nc_setting, nc_value, _asm, voice, level = v[:6]
            self.wind = nc_setting == 0x02
            if effect == 0x00:
                mode = "off"
            elif (nc_setting == 0x02 and nc_value >= 1) or (nc_setting == 0x00 and nc_value == 1):
                mode = "nc"
            else:
                mode = "ambient"
            self._apply(["nc", "ambient", "off"], mode, voice, level)
        elif kind in (0x19, 0x17, 0x15) and len(v) >= 5:
            _chg, on, nc_or_amb, voice, level = v[:5]
            modes = ["nc", "ambient", "off"]
            if kind == 0x19 and len(v) >= 7:
                self.auto, self.sensitivity = v[5], v[6]
                modes.append("adaptive")
            mode = "off" if not on else "nc" if nc_or_amb == 0 else "adaptive" if kind == 0x19 and self.auto else "ambient"
            if kind == 0x19 and reply:
                # WH-1000XM6 quirk (seen on real hardware): the reply to a
                # query always carries on/off = 0, so "noise cancelling" and
                # "off" read the same. Only notifications are exact. Ambient
                # still shows through its own byte; otherwise the mode is
                # left unknown and the UI keeps the last one it saw.
                mode = ("adaptive" if self.auto else "ambient") if nc_or_amb else None
            self.nc_type = kind
            self._apply(modes, mode, voice, level)
        elif kind == 0x22 and len(v) >= 4:
            _chg, on, voice, level = v[:4]
            self.nc_type = kind
            self._apply(["ambient", "off"], "ambient" if on else "off", voice, level)

    def _apply(self, modes, mode, voice, level):
        self.features.update({"modes": modes, "ambientMax": AMBIENT_MAX, "voice": True})
        self.voice = bool(voice)
        if level <= AMBIENT_MAX:
            self.level = level
        self.state.update({"mode": mode, "voice": self.voice, "ambient": self.level})
        self.mark_ready()

    def _on_battery(self, p):
        # The status byte is a bit field: bit 0 = charging. Older models send
        # 01, the WH-1000XM6 sends 03 while charging (seen on real hardware)
        kind, v = p[1], p[2:]
        if kind in (0x00, 0x08) and len(v) >= 2:
            self.set_battery("single", v[0], v[1] & 0x01)
        elif kind in (0x01, 0x09) and len(v) >= 4:
            # A level of 0 means that earbud is not connected
            if v[0]:
                self.set_battery("left", v[0], v[1] & 0x01)
            if v[2]:
                self.set_battery("right", v[2], v[3] & 0x01)
        elif kind in (0x02, 0x0A) and len(v) >= 2:
            self.set_battery("case", v[0], v[1] & 0x01)

    def _on_speak_to_chat(self, p):
        if self.version == 2 and p[1] == 0x0C and len(p) >= 3:
            self.state["chat"] = p[2] == 0x00  # v2 inverts it: 00 means on
        elif self.version == 1 and p[1] == 0x05 and len(p) >= 4 and p[2] == 0x01:
            self.state["chat"] = bool(p[3])

    # --- commands -------------------------------------------------------------

    def _noise_payload(self, mode):
        on = 0 if mode == "off" else 1
        ambient = 0 if mode == "nc" else 1
        voice, level = int(self.voice), self.level
        if self.version == 1:
            nc_setting = 0x02 if self.wind else 0x00
            nc_value = (0x02 if self.wind else 0x01) if mode == "nc" else 0x00
            return bytes([0x68, 0x02, 0x11 if on else 0x00, nc_setting, nc_value, 0x01, voice, level])
        if self.nc_type == 0x22:
            return bytes([0x68, 0x22, 0x01, on, voice, level])
        if self.nc_type == 0x19:
            auto = 1 if mode == "adaptive" else 0 if mode == "ambient" else self.auto
            return bytes([0x68, 0x19, 0x01, on, ambient, voice, level, auto, self.sensitivity])
        return bytes([0x68, self.nc_type, 0x01, on, ambient, voice, level])

    def _send_noise(self, mode):
        if self.nc_type is None:
            return
        if mode == "adaptive":
            self.auto = 1
        elif mode == "ambient":
            self.auto = 0
        self._queue(self._noise_payload(mode))
        self.state["mode"] = mode

    def set_mode(self, mode):
        self._send_noise(mode)

    def set_ambient(self, level):
        self.level = level
        self.state["ambient"] = level
        # The level lives in the ambient command: entering ambient if needed
        self._send_noise(self.state["mode"] if self.state["mode"] in ("ambient", "adaptive") else "ambient")

    def set_voice(self, enabled):
        self.voice = enabled
        self.state["voice"] = enabled
        self._send_noise(self.state["mode"] if self.state["mode"] in ("ambient", "adaptive") else "ambient")

    def set_chat(self, enabled):
        if self.version == 2:
            self._queue(bytes([0xF8, 0x0C, 0x00 if enabled else 0x01, 0x01]))
        else:
            self._queue(bytes([0xF8, 0x05, 0x01, 0x01 if enabled else 0x00]))
        self.state["chat"] = enabled

    def refresh(self):
        if self.version == 2 and self.nc_type:
            self._queue(bytes([0x66, self.nc_type]))
        elif self.version == 1:
            self._queue(b"\x66\x02")
