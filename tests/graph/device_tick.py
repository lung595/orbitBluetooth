#!/usr/bin/env python3
"""A device's volume tick on a PRIVATE PipeWire + WirePlumber: does it stay in that device? (NAK-255)

usage: python3 tests/graph/device_tick.py        (from the plugin root; ~60 s)

The owner's setup, made up: a wired output (a sound card) and a Bluetooth
headset with Orbit's PC-level filter in front of it, with and without Listen
together (the card as the source, the headset as its copy: their levels are
shared there, which is what used to make a headset tick sound in the card).
For each hand (the card's own level, the headset's PC level, the group's
general level) tests/graph-ticks.js says in which outputs Orbit plays the tick;
the real helper (tick/orbit_tick.py) plays it there, and each output's input
is recorded. The counter-proof runs the old choice (every shared output) and
must leak. Reuses the PipeWire plumbing of wired_tick.py. Exit 0 when all hold.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wired_tick as w  # noqa: E402

HEARD = w.HEARD


def plan(hand, old=False):
    out = subprocess.run(["gjs", w.ROOT + "/tests/graph-ticks.js", w.WIRED, w.BLUE, w.TOKEN, hand] + (["old"] if old else []),
                         check=True, capture_output=True, text=True)
    return json.loads(out.stdout)


def tick_sinks(env, tmp, sinks):
    """The peak heard on the card and on the headset while the tick plays in `sinks`."""
    def play():
        for s in sinks:
            w.tick(env, s)
    # Each tick plays for about 2 s, one after the other
    return w.heard_when(env, tmp, [w.WIRED, w.BLUE], play, 2 + 2 * len(sinks))


def cases(env, tmp, title, grouped):
    hands = (("wired", {w.WIRED}), ("bluetooth", {w.BLUE})) + ((("group", {w.WIRED, w.BLUE}),) if grouped else ())
    for hand, wanted in hands:
        sinks = plan(hand)["sinks"]
        w.check("%s, %s: the tick is asked in %s" % (title, hand, sorted(wanted)), set(sinks) == wanted)
        heard = tick_sinks(env, tmp, sinks)
        for sink in (w.WIRED, w.BLUE):
            w.check("%s, %s: %s %s" % (title, hand, "card" if sink == w.WIRED else "headset", "ticks" if sink in wanted else "stays silent"),
                    (heard[sink] > HEARD) == (sink in wanted))


def main():
    tmp = tempfile.mkdtemp(prefix="orbit-graph-")
    env = w.environment(tmp)
    try:
        w.spawn(["pipewire"], env)
        time.sleep(1.5)
        w.spawn(["wireplumber"], env)
        time.sleep(2.5)
        for name in (w.WIRED, w.BLUE):
            w.make_sink(env, name)
        time.sleep(1)
        # The headset's PC-level filter, as AudioRoute starts it (Route.filterArgs)
        filt = w.spawn(plan("group")["filter"], env)
        time.sleep(2.0)

        print("-- no group")
        cases(env, tmp, "no group", False)

        print("-- Listen together, the card is the source")
        copies = w.run_copies(env, w.WIRED, w.BLUE, w.TOKEN, 0)
        cases(env, tmp, "Listen together", True)
        # Counter-proof: the old choice ticked every shared output for a member's own level
        heard = tick_sinks(env, tmp, plan("bluetooth", old=True)["sinks"])
        w.check("old choice: the headset's own tick leaks into the card", heard[w.WIRED] > HEARD)
        for p in copies:
            w.stop(p)
        w.stop(filt)
    finally:
        for p in reversed(w.procs):
            w.stop(p)
        shutil.rmtree(tmp, ignore_errors=True)
    print("all passed" if not w.failures else "%d failed" % len(w.failures))
    return 1 if w.failures else 0


if __name__ == "__main__":
    sys.exit(main())
