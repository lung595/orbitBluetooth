"""SAFER+ as used by Xiaomi's earbuds to answer their login challenge.

SAFER+ is the public block cipher of classic Bluetooth pairing (Bluetooth
Core, Vol 2 Part H, the E1 function and its Ar' variant). The earbuds'
check is Ar' keyed with their 16-byte challenge (last byte XOR 6) on a
fixed plaintext; this file only follows that public algorithm.
"""

# Positions using XOR / exp in each round (1) versus ADD / log (0)
PATTERN = 0x9999
PLAINTEXT = bytes([0x11, 0x22, 0x33, 0x33, 0x22, 0x11, 0x11, 0x22, 0x33, 0x33, 0x22, 0x11, 0x11, 0x22, 0x33, 0x33])

# The SAFER+ mixing layer (Armenian shuffle + pseudo-Hadamard transforms)
# written as one 16x16 matrix, applied modulo 256
MIX = [
    [2, 1, 1, 1, 4, 2, 1, 1, 2, 2, 4, 2, 4, 4, 16, 8],
    [2, 1, 1, 1, 4, 2, 1, 1, 1, 1, 2, 1, 2, 2, 8, 4],
    [1, 1, 4, 2, 2, 2, 4, 2, 16, 8, 4, 4, 2, 1, 1, 1],
    [1, 1, 4, 2, 1, 1, 2, 1, 8, 4, 2, 2, 2, 1, 1, 1],
    [16, 8, 2, 2, 4, 2, 4, 4, 1, 1, 4, 2, 1, 1, 2, 1],
    [8, 4, 1, 1, 2, 1, 2, 2, 1, 1, 4, 2, 1, 1, 2, 1],
    [2, 2, 4, 2, 4, 4, 16, 8, 2, 1, 1, 1, 4, 2, 1, 1],
    [1, 1, 2, 1, 2, 2, 8, 4, 2, 1, 1, 1, 4, 2, 1, 1],
    [4, 2, 4, 4, 16, 8, 2, 2, 1, 1, 2, 1, 1, 1, 4, 2],
    [2, 1, 2, 2, 8, 4, 1, 1, 1, 1, 2, 1, 1, 1, 4, 2],
    [4, 4, 16, 8, 1, 1, 2, 1, 4, 2, 1, 1, 4, 2, 2, 2],
    [2, 2, 8, 4, 1, 1, 2, 1, 4, 2, 1, 1, 2, 1, 1, 1],
    [1, 1, 2, 1, 1, 1, 4, 2, 4, 4, 16, 8, 2, 2, 4, 2],
    [1, 1, 2, 1, 1, 1, 4, 2, 2, 2, 8, 4, 1, 1, 2, 1],
    [4, 2, 1, 1, 2, 1, 1, 1, 4, 2, 2, 2, 16, 8, 4, 4],
    [4, 2, 1, 1, 2, 1, 1, 1, 2, 1, 1, 1, 8, 4, 2, 2],
]

# exp(x) = 45^x mod 257 (256 stored as 0), and its inverse
EXP = [pow(45, x, 257) % 256 for x in range(256)]
LOG = [0] * 256
for _x, _v in enumerate(EXP):
    LOG[_v] = _x


def _xor_pos(i):
    return (PATTERN >> i) & 1


def key_schedule(key):
    """The 17 round keys: rotate a 17-byte register left by 3 each time and
    add the bias vectors B2..B17 (B_p[j] = 45^(45^(17p + j + 1) mod 257) mod 257)."""
    key = bytearray(key)
    key[15] ^= 6
    register = list(key)
    parity = 0
    for b in key:
        parity ^= b
    register.append(parity)
    keys = [bytes(key)]
    for p in range(1, 17):
        register = [((b << 3) | (b >> 5)) & 0xFF for b in register]
        bias = [pow(45, pow(45, 17 * (p + 1) + j + 1, 257), 257) % 256 for j in range(16)]
        keys.append(bytes((register[(p + j) % 17] + bias[j]) & 0xFF for j in range(16)))
    return keys


def respond(challenge):
    """Ar'(challenge, PLAINTEXT): the answer the earbuds expect."""
    keys = key_schedule(challenge)
    block = list(PLAINTEXT)
    for rnd in range(8):
        if rnd == 2:
            # Ar' feeds the input back in before the third round
            block = [(b ^ p) if _xor_pos(i) else (b + p) & 0xFF for i, (b, p) in enumerate(zip(block, PLAINTEXT))]
        k1, k2 = keys[2 * rnd], keys[2 * rnd + 1]
        block = [(b ^ k1[i]) if _xor_pos(i) else (b + k1[i]) & 0xFF for i, b in enumerate(block)]
        block = [EXP[b] if _xor_pos(i) else LOG[b] for i, b in enumerate(block)]
        block = [(b + k2[i]) & 0xFF if _xor_pos(i) else (b ^ k2[i]) for i, b in enumerate(block)]
        block = [sum(MIX[i][j] * block[j] for j in range(16)) & 0xFF for i in range(16)]
    k = keys[16]
    return bytes((b ^ k[i]) if _xor_pos(i) else (b + k[i]) & 0xFF for i, b in enumerate(block))
