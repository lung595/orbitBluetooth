"""Sony v2 extras beyond noise control, mixed into the Sony protocol.

- Wearing detection: the headset's proximity sensor, kept in table 2.
- How long a Speak-to-Chat conversation lasts before it ends by itself.

Packet layouts come from mos9527/SonyHeadphonesClient (MIT; no code copied).
The wearing flow was validated on a WH-1000XM6 (firmware 27.02) by phedoreanu's
pull request #63 there. Nothing here has been run against a real headset by
Orbit yet: see "Not yet confirmed on a real headset" in docs/GUIDE.md.

Wearing, as the XM6 does it: it never pushes a table 2 notification on its
own, but once the operation log is switched on it writes "unitRemove" and
"unitWear" into it. Each of those entries is the cue to ask for the status
again; the answer carries 00 (worn), 04 (both off) or a one-sided code.
"""

from .sony_frame import T_DATA2

# Table 1 support functions that imply the wearing sensor exists. The XM6
# answers the table 2 status but never lists it among its table 2 functions.
FN_WEAR = (0xF1, 0xF6)

LOG_ENABLE = b"\xc4\x01\x00"      # switch the time-series operation log on
T2_FUNCTIONS = b"\x06\x00"        # table 2 support list, asked before using it
ASK_WEAR = b"\xf2\x00"            # table 2: wearing status request
LOG_KEYS = (b"unitRemove", b"unitWear")

WEAR_MAX = 0x04                   # highest status code the headset documents
CHAT_SENSITIVITY_MAX = 0x02       # 00 automatic, 01 high, 02 low
CHAT_ENDS_MAX = 0x03              # 00 short, 01 standard, 02 long, 03 never


class SonyExtras:
    def init_extras(self):
        self.table2 = False              # the headset speaks the second table
        self.wear = False                # wear reports were asked for
        self.wear_started = False        # log switched on during this session
        self.chat_sensitivity = 0        # kept: the write carries both bytes

    # --- wearing -------------------------------------------------------------

    def on_functions(self, codes):
        self.features["wear"] = self.table2 and any(code in codes for code in FN_WEAR)

    def set_wear(self, enabled):
        self.wear = enabled
        if not enabled:
            self.state["wearing"] = None
            return
        if not self.wear_started:
            self.wear_started = True
            self._queue(LOG_ENABLE)
            self._queue(T2_FUNCTIONS, T_DATA2)
        self._ask_wear()

    def _ask_wear(self):
        if (T_DATA2, ASK_WEAR) not in self.queue:
            self._queue(ASK_WEAR, T_DATA2)

    def on_unit_log(self, p):
        # C9 01 <length> <key>: only the two sensor entries matter
        if self.wear and len(p) >= 3 and p[1] == 0x01 and bytes(p[3:3 + p[2]]) in LOG_KEYS:
            self._ask_wear()

    def data2(self, p):
        # The reply (F3) and a notification (F5) share one layout: F? 00 <status>
        if self.wear and p[0] in (0xF3, 0xF5) and len(p) >= 3 and p[1] == 0x00 and p[2] <= WEAR_MAX:
            self.state["wearing"] = p[2]

    # --- how long a conversation lasts --------------------------------------

    def on_chat_ends(self, p):
        # FB (reply) and FD (notification): <FB|FD> 0C <sensitivity> <duration>
        if len(p) >= 4 and p[1] == 0x0C and p[2] <= CHAT_SENSITIVITY_MAX and p[3] <= CHAT_ENDS_MAX:
            self.chat_sensitivity = p[2]
            self.state["chatEnds"] = p[3]
            self.features["chatEnds"] = True

    def set_chat_ends(self, duration):
        # The write replaces both bytes: the sensitivity is sent back as read
        self._queue(bytes([0xFC, 0x0C, self.chat_sensitivity, duration]))
        self.state["chatEnds"] = duration
