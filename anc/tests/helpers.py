"""Helpers shared by the protocol tests: hex to bytes, and a started protocol with its sent list."""

from protocols import FAMILIES


def h(text):
    return bytes.fromhex(text.replace(" ", ""))


def make(family, name=""):
    sent = []
    proto = FAMILIES[family](sent.append, name)
    proto.start()
    return proto, sent
