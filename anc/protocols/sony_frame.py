"""Sony "MDR" framing: how one packet is escaped, checksummed and unpacked.

Written from the byte-level facts documented by Gadgetbridge and
mos9527/SonyHeadphonesClient (no code copied).

Frame: 3E | escaped(type, seq, length u32 BE, payload, checksum) | 3C
- checksum = sum of the unescaped bytes from type to payload, mod 256;
- 3C/3D/3E inside a frame are sent as 3D followed by (byte & EF).

Types: 0C carries "table 1" payloads, 0E "table 2" payloads (a second
command set some v2 models use for things like the wearing sensor), 01
acknowledges either.
"""

START, END, ESCAPE = 0x3E, 0x3C, 0x3D
T_ACK, T_DATA, T_DATA2 = 0x01, 0x0C, 0x0E


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
