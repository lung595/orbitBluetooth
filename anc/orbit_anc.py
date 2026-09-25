#!/usr/bin/env python3
"""Orbit ANC helper: talks to one headset's vendor protocol.

Started by OrbitBluetoothDaemon.qml, never by itself:

    python3 orbit_anc.py <address> <family>

- stdin: one command per line: "get", "set <key> <value>".
- stdout: one JSON object per line, whenever something changes:
      {"status": "connecting" | "ready" | "error", "error": "...",
       "features": {...}, "state": {...}}
- Closing stdin ends the session once pending commands are answered, so the
  daemon can run it "on demand" (open, send, close) or keep it open while a
  headset stays connected ("always connected" engine setting).

Privacy: it only opens a local Bluetooth socket to the given address. No
network, no files, no logging beyond stderr (raw packets only when
ORBIT_ANC_DEBUG=1).
"""

import json
import os
import selectors
import socket
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import sdp  # noqa: E402
from protocols import FAMILIES  # noqa: E402

CONNECT_TIMEOUT = 8.0
# After stdin closes, wait this long for the headset to confirm the last change
LINGER_SECONDS = 1.5
HANDSHAKE_GRACE = 6.0
# Give up when the headset never completes its handshake
HANDSHAKE_TIMEOUT = 10.0
# While shaking hands the protocol may need tick() for retries; once ready,
# the loop blocks until the headset or the daemon says something.
HANDSHAKE_POLL = 0.25
# Right after the handshake the first answers (battery, Speak-to-Chat...)
# arrive one by one, some after their acknowledgement; they are held back
# this long and sent as one update so the detail card settles once instead
# of growing in steps.
SETTLE_SECONDS = 0.5


# ORBIT_ANC_DEBUG=1 prints every raw packet to stderr (never to a file), to
# compare a headset's behaviour with a protocol spec.
DEBUG = os.environ.get("ORBIT_ANC_DEBUG") == "1"


def trace(direction, data):
    if DEBUG:
        sys.stderr.write("%s %s\n" % (direction, data.hex(" ")))
        sys.stderr.flush()


def emit(message):
    sys.stdout.write(json.dumps(message, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def open_socket(address, transport):
    """Opens the socket described by a protocol's `transport` tuple."""
    kind = transport[0]
    if kind == "l2cap":
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
        target = (address, transport[1])
    else:
        # ("rfcomm", [uuid, ...], fallback channel or None)
        channel = None
        for service in transport[1]:
            try:
                channel = sdp.find_rfcomm_channel(address, service)
            except OSError:
                channel = None
            if channel:
                break
        channel = channel or transport[2]
        if not channel:
            raise OSError("vendor service not found")
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
        target = (address, channel)
    sock.settimeout(CONNECT_TIMEOUT)
    sock.connect(target)
    sock.setblocking(False)
    return sock


def parse_command(line):
    """'set mode nc' -> ('set', 'mode', 'nc'); values stay strings."""
    parts = line.split()
    if not parts:
        return None
    if parts[0] == "set" and len(parts) == 3:
        return ("set", parts[1], parts[2])
    if parts[0] == "get":
        return ("get",)
    return None


def handle_command(proto, command):
    if not command:
        return
    if command[0] == "get":
        proto.refresh()
    elif proto.ready:
        proto.set(command[1], command[2])
    else:
        # Applied as soon as the handshake completes
        proto.pending.append(command[1:])


def run(address, family):
    factory = FAMILIES.get(family)
    if not factory:
        emit({"status": "error", "error": "unsupported"})
        return 2
    emit({"status": "connecting"})
    try:
        sock = open_socket(address, factory.transport)
    except OSError as err:
        emit({"status": "error", "error": str(err) or "connection failed"})
        return 1

    def send(data):
        trace(">>", data)
        sock.sendall(data)

    proto = factory(send)
    selector = selectors.DefaultSelector()
    selector.register(sock, selectors.EVENT_READ, "socket")
    selector.register(sys.stdin, selectors.EVENT_READ, "stdin")

    stdin_open = True
    pending_input = b""
    deadline = None
    last = {"status": "connecting"}  # already announced above
    proto.start()
    started = time.monotonic()
    ready_at = None
    try:
        while True:
            now = time.monotonic()
            if deadline is not None and now >= deadline:
                break
            if not proto.ready and now - started > HANDSHAKE_TIMEOUT:
                raise TimeoutError("timed out")
            settling = ready_at is not None and now - ready_at < SETTLE_SECONDS
            timeout = HANDSHAKE_POLL if settling or not proto.ready else None
            if deadline is not None:
                timeout = min(timeout or deadline - now, deadline - now)
            for key, _ in selector.select(timeout):
                if key.data == "socket":
                    data = sock.recv(4096)
                    if not data:
                        raise ConnectionError("headset closed the connection")
                    trace("<<", data)
                    proto.receive(data)
                else:
                    # Raw reads: buffered readline() could hide lines from select()
                    chunk = os.read(sys.stdin.fileno(), 4096)
                    if not chunk:
                        # Session over: let the headset answer, then leave
                        selector.unregister(sys.stdin)
                        stdin_open = False
                        # A headset still shaking hands gets a longer grace period
                        deadline = time.monotonic() + (LINGER_SECONDS if proto.ready else HANDSHAKE_GRACE)
                        continue
                    pending_input += chunk
                    while b"\n" in pending_input:
                        line, pending_input = pending_input.split(b"\n", 1)
                        handle_command(proto, parse_command(line.decode("utf-8", "ignore")))
            proto.tick(time.monotonic())
            now = time.monotonic()
            if proto.ready and ready_at is None:
                ready_at = now
            settling = ready_at is not None and now - ready_at < SETTLE_SECONDS
            snapshot = proto.snapshot()
            if snapshot != last and not (settling and snapshot["status"] == "ready"):
                last = snapshot
                emit(snapshot)
            if not stdin_open and proto.ready and not proto.pending and not proto.awaiting:
                # Everything answered: no need to wait for the full linger
                deadline = min(deadline, time.monotonic() + 0.2)
    except (OSError, ConnectionError) as err:
        emit({"status": "error", "error": str(err) or "connection lost"})
        return 1
    finally:
        sock.close()
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.stderr.write(__doc__)
        sys.exit(2)
    sys.exit(run(sys.argv[1], sys.argv[2]))
