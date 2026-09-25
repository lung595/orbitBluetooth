"""Sony headphones: the "MDR" protocol over RFCOMM (v1 and v2).

Written from the byte-level facts documented by Gadgetbridge and
mos9527/SonyHeadphonesClient (no code copied).

Frame: 3E | escaped(type, seq, length u32 BE, payload, checksum) | 3C
- checksum = sum of the unescaped bytes from type to payload, mod 256;
- 3C/3D/3E inside a frame are sent as 3D followed by (byte & EF);
- every data frame from the headset must be acknowledged, and we keep only
  one command in flight until the headset acknowledges it.

v1 (WH-1000XM3/XM4, WF-1000XM3...) and v2 (WH-1000XM5/XM6, WF-1000XM4/XM5,
LinkBuds, ULT...) share the framing but not every payload. On v2 the list of
supported functions tells which noise-control layout the model expects.
"""

from .base import Protocol

UUID_V2 = "956c7b26-d49a-4ba8-b03f-b17d393cb6e2"
UUID_V1 = "96cc203e-5068-46ad-b32d-e316f5e069ba"

START, END, ESCAPE = 0x3E, 0x3C, 0x3D
T_ACK, T_DATA, T_DATA2 = 0x01, 0x0C, 0x0E

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


def encode(dtype, seq, payload):
    body = bytes([dtype, seq]) + len(payload).to_bytes(4, "big") + bytes(payload)
    raw = body + bytes([sum(body) & 0xFF])
    out = bytearray([START])
    for b in raw:
        out += bytes([ESCAPE, b & 0xEF]) if b in (START, END, ESCAPE) else bytes([b])
    out.append(END)
    return bytes(out)


def decode(escaped):
    """Unescaped (type, seq, payload) of the bytes between 3E and 3C, or None."""
    raw, i = bytearray(), 0
    while i < len(escaped):
        if escaped[i] == ESCAPE and i + 1 < len(escaped):
            raw.append(escaped[i + 1] | 0x10)
            i += 2
        else:
            raw.append(escaped[i])
            i += 1
    if len(raw) < 7:
        return None
    length = int.from_bytes(raw[2:6], "big")
    if len(raw) != 7 + length or sum(raw[:-1]) & 0xFF != raw[-1]:
        return None
    return raw[0], raw[1], bytes(raw[6:6 + length])


class Sony(Protocol):
    transport = ("rfcomm", [UUID_V2, UUID_V1], None)

    def __init__(self, send):
        super().__init__(send)
        self.version = 0          # 1 or 2 once the headset answered the init
        self.seq = 0              # our sequence number, flipped by each ACK
        self.queue = []           # payloads waiting for the one in flight
        self.inflight = None      # (payload, sent at, tries)
        self.nc_type = None       # v2 layout byte (0x19, 0x17, 0x15, 0x22), 0x02 on v1
        self.nc_candidates = []   # v2 layouts still to try when the list is silent
        self.wind = False         # v1 models with a wind-reduction setting
        self.auto = 0             # XM6 automatic ambient (0x19 only)
        self.sensitivity = 0
        self.level = 10           # ambient level, kept while in other modes
        self.voice = False

    # --- transport ---------------------------------------------------------

    def start(self):
        self._queue(b"\x00\x00")  # protocol info: tells v1 from v2

    def _queue(self, payload):
        self.queue.append(bytes(payload))
        self._pump()

    def _pump(self, now=None):
        if self.inflight is None and self.queue:
            payload = self.queue.pop(0)
            self.send(encode(T_DATA, self.seq, payload))
            self.inflight = (payload, now, 1)
        self.awaiting = len(self.queue) + (1 if self.inflight else 0)

    def tick(self, now):
        if not self.inflight:
            return
        payload, sent, tries = self.inflight
        if sent is None:
            self.inflight = (payload, now, tries)
        elif now - sent > RETRY_SECONDS:
            if tries >= MAX_TRIES:
                # Unanswered: move on (unknown command on this model)
                self.inflight = None
                self._on_silence(payload)
            else:
                self.send(encode(T_DATA, self.seq, payload))
                self.inflight = (payload, now, tries + 1)
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

    def _on_protocol_info(self, p):
        if self.version:
            return
        self.version = 2 if len(p) >= 8 else 1
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
        kind, v = p[1], p[2:]
        if kind in (0x00, 0x08) and len(v) >= 2:
            self.set_battery("single", v[0], v[1] == 1)
        elif kind in (0x01, 0x09) and len(v) >= 4:
            # A level of 0 means that earbud is not connected
            if v[0]:
                self.set_battery("left", v[0], v[1] == 1)
            if v[2]:
                self.set_battery("right", v[2], v[3] == 1)
        elif kind in (0x02, 0x0A) and len(v) >= 2:
            self.set_battery("case", v[0], v[1] == 1)

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
