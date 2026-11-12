"""Minimal SDP client: find the RFCOMM channel of a service by its UUID.

Vendor services (Sony, Samsung, Nothing...) do not use a fixed RFCOMM
channel, so it must be looked up in the headset's SDP records. Python has no
SDP API and `sdptool` is deprecated, so this asks the headset directly with a
single ServiceSearchAttributeRequest over L2CAP PSM 1 (Bluetooth Core spec,
Vol 3, Part B). Only the ProtocolDescriptorList attribute is requested.
"""

import socket
import struct
import uuid as uuidlib

SDP_PSM = 1
ATTR_PROTOCOL_DESCRIPTOR_LIST = 0x0004
UUID_RFCOMM = 0x0003

PDU_SEARCH_ATTR_REQUEST = 0x06
PDU_SEARCH_ATTR_RESPONSE = 0x07

# Data element types (the upper 5 bits of the header byte)
T_NIL, T_UINT, T_INT, T_UUID, T_TEXT, T_BOOL, T_SEQ, T_ALT, T_URL = range(9)

# The answer comes from the headset, so it is bounded: real records nest 3 or
# 4 deep and fit in one or two PDUs. Past these limits the reply is garbage
# (or hostile) and the lookup gives up instead of recursing or looping.
MAX_DEPTH = 8
MAX_ROUNDS = 16
MAX_COLLECTED = 64 * 1024
# RFCOMM server channels are 1 to 30 (RFCOMM spec, TS 07.10 adaptation)
RFCOMM_CHANNELS = range(1, 31)


class SdpError(OSError):
    """A malformed SDP reply: treated like an unreachable service."""


def parse_element(buf, pos=0, depth=0):
    """Decode one data element; returns (value, next position).

    Sequences become Python lists, UUIDs become ints (16/32-bit) or
    uuid.UUID (128-bit), integers become ints and text becomes bytes.
    """
    if depth > MAX_DEPTH:
        raise SdpError("SDP reply nested too deep")
    if pos >= len(buf):
        raise SdpError("truncated SDP element")
    head = buf[pos]
    kind, size_index = head >> 3, head & 7
    pos += 1
    if kind == T_NIL:
        return None, pos
    if size_index < 5:
        size = (1, 2, 4, 8, 16)[size_index]
    else:
        width = (1, 2, 4)[size_index - 5]
        size = int.from_bytes(buf[pos:pos + width], "big")
        pos += width
    data = buf[pos:pos + size]
    end = pos + size
    if kind in (T_SEQ, T_ALT):
        items, inner = [], 0
        while inner < len(data):
            value, inner = parse_element(data, inner, depth + 1)
            items.append(value)
        return items, end
    if kind == T_UUID:
        return (uuidlib.UUID(bytes=bytes(data)) if size == 16 else int.from_bytes(data, "big")), end
    if kind == T_UINT:
        return int.from_bytes(data, "big"), end
    if kind == T_INT:
        return int.from_bytes(data, "big", signed=True), end
    if kind == T_BOOL:
        return (len(data) > 0 and data[0] != 0), end
    return bytes(data), end


def build_request(service_uuid, transaction=1, continuation=b""):
    """ServiceSearchAttributeRequest for one 128-bit UUID and attribute 0x0004."""
    pattern = b"\x35\x11\x1c" + uuidlib.UUID(service_uuid).bytes
    attributes = b"\x35\x03\x09" + struct.pack(">H", ATTR_PROTOCOL_DESCRIPTOR_LIST)
    params = pattern + struct.pack(">H", 0xFFFF) + attributes + bytes([len(continuation)]) + continuation
    return struct.pack(">BHH", PDU_SEARCH_ATTR_REQUEST, transaction, len(params)) + params


def split_response(pdu):
    """Returns (attribute list bytes, continuation state) of one response PDU."""
    if len(pdu) < 5:
        raise SdpError("truncated SDP reply")
    pdu_id, _transaction, _length = struct.unpack(">BHH", pdu[:5])
    if pdu_id != PDU_SEARCH_ATTR_RESPONSE:
        raise SdpError("SDP error response")
    if len(pdu) < 7:
        raise SdpError("truncated SDP reply")
    count = struct.unpack(">H", pdu[5:7])[0]
    if len(pdu) < 8 + count:
        raise SdpError("truncated SDP reply")
    lists = pdu[7:7 + count]
    cont_len = pdu[7 + count]
    return lists, pdu[8 + count:8 + count + cont_len]


def rfcomm_channel(attribute_lists):
    """Finds the RFCOMM channel inside the decoded attribute lists, or None."""
    records, _ = parse_element(attribute_lists)
    # Every level is checked for its type: a reply of the wrong shape means
    # "no channel", never an exception (P-audit 2026-11)
    for record in records if isinstance(records, list) else []:
        if not isinstance(record, list):
            continue
        # record = [attrId, value, attrId, value, ...]
        for i in range(0, len(record) - 1, 2):
            if record[i] != ATTR_PROTOCOL_DESCRIPTOR_LIST or not isinstance(record[i + 1], list):
                continue
            for layer in record[i + 1]:
                if isinstance(layer, list) and len(layer) >= 2 and layer[0] == UUID_RFCOMM:
                    channel = layer[1]
                    if isinstance(channel, int) and not isinstance(channel, bool) and channel in RFCOMM_CHANNELS:
                        return channel
    return None


def find_rfcomm_channel(address, service_uuid, timeout=5.0):
    """Asks the device which RFCOMM channel serves `service_uuid`."""
    sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
    sock.settimeout(timeout)
    try:
        sock.connect((address, SDP_PSM))
        collected, continuation, transaction = b"", b"", 1
        seen = set()
        while True:
            sock.send(build_request(service_uuid, transaction, continuation))
            lists, continuation = split_response(sock.recv(4096))
            collected += lists
            if not continuation:
                break
            # A headset that keeps answering "more" (or repeats itself) would
            # hold the helper here for ever, out of the shell's reach
            if continuation in seen or transaction >= MAX_ROUNDS or len(collected) > MAX_COLLECTED:
                raise SdpError("SDP reply never ends")
            seen.add(continuation)
            transaction += 1
        if not collected:
            return None
        try:
            return rfcomm_channel(collected)
        except (IndexError, ValueError, TypeError) as err:
            raise SdpError("malformed SDP reply") from err
    finally:
        sock.close()
