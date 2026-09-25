"""Shared shape of every vendor protocol.

Each brand module subclasses Protocol and only deals with bytes: framing,
the handshake, and turning packets into the common state below. The runner
(orbit_anc.py) owns the socket and the stdin/stdout plumbing.

Common vocabulary, used as-is by the QML side:
  features = {
      "modes":      ["off", "nc", "ambient", "adaptive"]  (subset, in cycle order)
      "ambientMax": highest level of the slider, 0 when there is no slider
      "levelMode":  mode the slider belongs to: "ambient" (ambient level) or
                    "adaptive" (AirPods adaptive noise level)
      "voice":      True when "focus on voice" exists
      "chat":       True when a conversation-detection feature exists
  }
  state = {
      "mode": "off" | "nc" | "ambient" | "adaptive" | None,
      "ambient": int | None, "voice": bool | None, "chat": bool | None,
      "battery": {"left"|"right"|"case"|"single": {"level": 0-100, "charging": bool}}
  }
"""

import copy

MODES = ("off", "nc", "ambient", "adaptive")


class Protocol:
    # ("rfcomm", [service uuids], fallback channel) or ("l2cap", psm)
    transport = None

    def __init__(self, send):
        self._send = send
        self.buffer = bytearray()
        self.ready = False
        # "set" commands received before the handshake finished
        self.pending = []
        # number of our writes the headset has not acknowledged yet
        self.awaiting = 0
        self.model = ""
        self.features = {"modes": [], "ambientMax": 0, "levelMode": "ambient", "voice": False, "chat": False}
        self.state = {"mode": None, "ambient": None, "voice": None, "chat": None, "battery": {}}

    # --- to implement per brand ------------------------------------------

    def start(self):
        """Sends the handshake and the initial state queries."""
        raise NotImplementedError

    def frames(self):
        """Yields complete packets taken from self.buffer (and removes them)."""
        raise NotImplementedError

    def handle(self, frame):
        """Updates features/state from one packet."""
        raise NotImplementedError

    def set_mode(self, mode):
        raise NotImplementedError

    def set_ambient(self, level):
        """Ambient level; brands may also need the current mode and voice."""

    def set_voice(self, enabled):
        pass

    def set_chat(self, enabled):
        pass

    def refresh(self):
        """Asks the headset for its current state again."""

    def tick(self, now):
        """Called after every event, for retries or timeouts."""

    # --- shared plumbing ---------------------------------------------------

    def send(self, data):
        self._send(bytes(data))

    def receive(self, data):
        self.buffer += data
        for frame in self.frames():
            self.handle(frame)

    def mark_ready(self):
        if self.ready:
            return
        self.ready = True
        waiting, self.pending = self.pending, []
        for key, value in waiting:
            self.set(key, value)

    def set(self, key, value):
        """Dispatches a textual "set <key> <value>" command."""
        if key == "mode" and value in self.features["modes"]:
            self.set_mode(value)
        elif key == "ambient" and self.features["ambientMax"]:
            self.set_ambient(max(0, min(self.features["ambientMax"], int(value))))
        elif key == "voice" and self.features["voice"]:
            self.set_voice(value in ("1", "true", "on"))
        elif key == "chat" and self.features["chat"]:
            self.set_chat(value in ("1", "true", "on"))

    def set_battery(self, part, level, charging=False):
        if 0 <= level <= 100:
            self.state["battery"][part] = {"level": level, "charging": bool(charging)}

    def snapshot(self):
        # Deep copy: the runner compares snapshots to print only changes
        return copy.deepcopy({
            "status": "ready" if self.ready else "connecting",
            "model": self.model,
            "features": self.features,
            "state": self.state,
        })
