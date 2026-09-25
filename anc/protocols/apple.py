"""Apple AirPods and Beats: the Apple Accessory Protocol (AAP) over L2CAP.

Written from the byte-level facts documented by the LibrePods and
MagicPodsCore reverse-engineering projects (no code copied). Every data
packet is `04 00 04 00 <opcode u16 LE> <payload>`; settings travel as
11-byte "control" packets: `04 00 04 00 09 00 <id> <value> 00 00 00`.

There is no "get" command: after the handshake the AirPods push their
current mode, settings and battery on their own.
"""

from .base import Protocol

PSM = 0x1001
HEADER = b"\x04\x00\x04\x00"

HANDSHAKE = bytes.fromhex("00000400010002000000000000000000")
# Enables the extended features; without it Adaptive falls back to another mode
FEATURES = HEADER + bytes.fromhex("4d00ff00000000000000")
REQUEST_NOTIFICATIONS = HEADER + bytes.fromhex("0f00ffffffff")

OP_BATTERY = 0x04
OP_CONTROL = 0x09
OP_FEATURES_ACK = 0x2B
OP_INFO = 0x1D

CTRL_MODE = 0x0D
CTRL_ADAPTIVE_LEVEL = 0x2E
CTRL_CONVERSATION = 0x28
CTRL_ALLOW_OFF = 0x34

MODE_TO_BYTE = {"off": 1, "nc": 2, "ambient": 3, "adaptive": 4}
BYTE_TO_MODE = {v: k for k, v in MODE_TO_BYTE.items()}

BATTERY_PART = {0x01: "single", 0x02: "right", 0x04: "left", 0x08: "case"}
BATTERY_CHARGING, BATTERY_DISCONNECTED = 0x01, 0x04

# Model numbers (sent in the 0x1D info packet) of models with Adaptive mode:
# AirPods 4 (ANC), AirPods Pro 2 (Lightning and USB-C), AirPods Pro 3
ADAPTIVE_MODELS = {
    "A3055", "A3056", "A3057",
    "A2698", "A2699", "A2931",
    "A3047", "A3048", "A3049",
    "A3063", "A3064", "A3065",
}

# Seconds to wait for an ack before moving to the next handshake step anyway
STEP_TIMEOUT = 0.6
# Without any mode notification after this, the model has no noise control
MODE_TIMEOUT = 3.0


def control(ident, value):
    return HEADER + bytes([OP_CONTROL, 0x00, ident, value, 0x00, 0x00, 0x00])


def parse_battery(payload):
    """payload = count, then per part: component, 01, level, status, 01."""
    parts = {}
    count = payload[0] if payload else 0
    for i in range(count):
        record = payload[1 + i * 5:6 + i * 5]
        if len(record) < 5:
            break
        part = BATTERY_PART.get(record[0])
        level, status = record[2], record[3]
        # 127 and other values above 100 mean "unknown"
        if part and status != BATTERY_DISCONNECTED and level <= 100:
            parts[part] = (level, status == BATTERY_CHARGING)
    return parts


class Apple(Protocol):
    transport = ("l2cap", PSM)

    def __init__(self, send):
        super().__init__(send)
        self.features["levelMode"] = "adaptive"
        self._step = 0
        self._step_at = None
        self._allow_off = True
        self._adaptive = False
        self._has_modes = False

    def start(self):
        self.send(HANDSHAKE)
        self._step, self._step_at = 1, None

    # L2CAP keeps packet boundaries: one recv() is one packet
    def receive(self, data):
        self.handle(bytes(data))

    def frames(self):
        return []

    def _advance(self, now=None):
        if self._step == 1:
            self.send(FEATURES)
            self._step = 2
        elif self._step == 2:
            self.send(REQUEST_NOTIFICATIONS)
            self._step = 3
        self._step_at = now

    def tick(self, now):
        if self._step_at is None:
            self._step_at = now
            return
        if self._step in (1, 2) and now - self._step_at > STEP_TIMEOUT:
            self._advance(now)
        elif self._step == 3 and not self.ready and now - self._step_at > MODE_TIMEOUT:
            # Nothing pushed: an AirPods model without noise control
            self.mark_ready()

    def _update_modes(self):
        modes = ["off", "nc", "ambient"] if self._has_modes else []
        if modes and self._adaptive:
            modes.append("adaptive")
        if not self._allow_off and "off" in modes:
            # Off is disabled on the AirPods; changing that is a persistent
            # setting, so we leave it to the user's Apple device.
            modes.remove("off")
        self.features["modes"] = modes
        self.features["ambientMax"] = 100 if self._adaptive else 0

    def handle(self, packet):
        if packet.startswith(b"\x01\x00\x04\x00") and self._step == 1:
            self._advance()
            return
        if not packet.startswith(HEADER) or len(packet) < 6:
            return
        opcode = packet[4] | packet[5] << 8
        payload = packet[6:]
        if opcode == OP_FEATURES_ACK and self._step == 2:
            self._advance()
        elif opcode == OP_BATTERY:
            for part, (level, charging) in parse_battery(payload).items():
                self.set_battery(part, level, charging)
        elif opcode == OP_INFO:
            # name, model number, manufacturer, serials... Only the model
            # number is kept; serial numbers are never stored.
            fields = payload.split(b"\x00")
            if len(fields) > 1:
                self.model = fields[1].decode("ascii", "ignore").strip()
                self._adaptive = self._adaptive or self.model in ADAPTIVE_MODELS
                self._update_modes()
        elif opcode == OP_CONTROL and len(payload) >= 2:
            self._control(payload[0], payload[1])

    def _control(self, ident, value):
        if ident == CTRL_MODE and value in BYTE_TO_MODE:
            self._has_modes = True
            if value == MODE_TO_BYTE["adaptive"]:
                self._adaptive = True
            self.state["mode"] = BYTE_TO_MODE[value]
            self._update_modes()
            self.mark_ready()
        elif ident == CTRL_ADAPTIVE_LEVEL and value <= 100:
            self._adaptive = True
            self.state["ambient"] = value
            self._update_modes()
        elif ident == CTRL_CONVERSATION and value in (1, 2):
            self.features["chat"] = True
            self.state["chat"] = value == 1
        elif ident == CTRL_ALLOW_OFF and value in (1, 2):
            self._allow_off = value == 1
            self._update_modes()

    def set_mode(self, mode):
        self.send(control(CTRL_MODE, MODE_TO_BYTE[mode]))
        self.state["mode"] = mode

    def set_ambient(self, level):
        self.send(control(CTRL_ADAPTIVE_LEVEL, level))
        self.state["ambient"] = level

    def set_chat(self, enabled):
        # The AirPods do not echo this one: keep our own copy
        self.send(control(CTRL_CONVERSATION, 1 if enabled else 2))
        self.state["chat"] = enabled
