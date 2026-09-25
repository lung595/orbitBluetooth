"""Checksums shared by several vendor protocols."""


def crc16_xmodem(data):
    """CRC-16/XMODEM: poly 0x1021, init 0, not reflected (Samsung, Huawei)."""
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return crc


def crc16_modbus(data):
    """CRC-16/MODBUS: reflected poly 0xA001, init 0xFFFF (Nothing)."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc


def sum8(data):
    """Sum of the bytes, modulo 256 (Soundcore)."""
    return sum(data) & 0xFF
