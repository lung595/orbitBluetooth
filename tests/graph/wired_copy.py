#!/usr/bin/env python3
"""Listen together on a PRIVATE PipeWire + WirePlumber: does a wired source's sound reach its copies?

usage: python3 tests/graph/wired_copy.py        (from the plugin root; ~20 s)

Starts its own PipeWire and WirePlumber in a temporary runtime directory (the
bus, BlueZ and the sound cards are never touched: those monitors are switched
off), makes two made-up outputs (a wired source and a Bluetooth copy),
runs the very commands Listen together would run (tests/graph-commands.js:
the filter kept in front of the wired source, and the copies reading its
monitor) and records each output's input while a tone plays to the source.
Checked: the played sound still reaches the source, and the copied sound
reaches the copy, with and without a 150 ms wait.
Exit 0 when all hold.
Developer-only: building and recording the private graph needs pipewire-utils
(pw-cli, pw-cat, pw-link), which Orbit itself does not.
"""
import array
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import time
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WIRED = "alsa_output.usb-Acme_Demo-00.analog-stereo"
BLUE = "bluez_output.AA_BB_CC_DD_EE_01.1"
TOKEN = "AA:BB:CC:DD:EE:01"
RATE = 48000

procs = []
failures = []


def check(name, ok):
    print(("ok   " if ok else "FAIL ") + name)
    if not ok:
        failures.append(name)


def spawn(argv, env, **kw):
    p = subprocess.Popen(argv, env=env, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, **kw)
    procs.append(p)
    return p


def stop(p):
    # Closing the standard input is how Orbit's wrappers end; kill what is still there
    try:
        p.stdin.close()
    except Exception:
        pass
    try:
        p.wait(timeout=3)
    except subprocess.TimeoutExpired:
        p.kill()


def environment(tmp):
    run = tmp + "/run"
    home = tmp + "/home"
    os.makedirs(run, mode=0o700)
    os.makedirs(home + "/.config/wireplumber/wireplumber.conf.d")
    # No sound card, no Bluetooth, no camera: nothing of the real machine is seen
    with open(home + "/.config/wireplumber/wireplumber.conf.d/10-private.conf", "w") as f:
        f.write("wireplumber.profiles = { main = { monitor.alsa = disabled monitor.alsa-midi = disabled "
                "monitor.bluez = disabled monitor.bluez-midi = disabled monitor.libcamera = disabled monitor.v4l2 = disabled } }\n")
    env = {k: v for k, v in os.environ.items() if k != "DBUS_SESSION_BUS_ADDRESS"}
    env.update(XDG_RUNTIME_DIR=run, HOME=home, XDG_CONFIG_HOME=home + "/.config", XDG_STATE_HOME=home + "/.state",
               XDG_CACHE_HOME=home + "/.cache", PIPEWIRE_CORE="orbit-graph-test", PIPEWIRE_REMOTE="orbit-graph-test")
    return env


def start_graph(env):
    """PipeWire and WirePlumber, both private."""
    spawn(["pipewire"], env)
    time.sleep(1.5)
    spawn(["wireplumber"], env)
    time.sleep(2.0)


def make_sink(env, name):
    subprocess.run(["pw-cli", "create-node", "adapter",
                    "{ factory.name=support.null-audio-sink node.name=%s media.class=Audio/Sink object.linger=true audio.position=[FL FR] }" % name],
                   env=env, check=True, stdout=subprocess.DEVNULL)


def commands(source, copy, token, wait):
    out = subprocess.run(["gjs", ROOT + "/tests/graph-commands.js", source, copy, token, str(wait)], check=True, capture_output=True, text=True)
    return json.loads(out.stdout)["commands"]


def run_copies(env, source, copy, token, wait):
    started = [spawn(c["command"], env) for c in commands(source, copy, token, wait)]
    time.sleep(3.0)
    return started


recorders = [0]


def record(env, sink, path, seconds):
    # The input of an output: its own monitor ports, linked by hand. A recorder that names the
    # sink would be rerouted by WirePlumber to the smart filter in front of it, and would no
    # longer record what reaches the output itself.
    recorders[0] += 1
    name = "rec%d" % recorders[0]
    p = spawn(["timeout", str(seconds), "pw-cat", "--record", "-P", "node.name=%s node.autoconnect=false" % name,
               "--format", "f32", "--rate", str(RATE), "--channels", "2", path], env)
    for _ in range(40):
        ports = subprocess.run(["pw-link", "-i"], env=env, capture_output=True, text=True).stdout
        if name + ":input_FR" in ports:
            break
        time.sleep(0.05)
    for side in ("FL", "FR"):
        subprocess.run(["pw-link", "--", "%s:monitor_%s" % (sink, side), "%s:input_%s" % (name, side)], env=env, capture_output=True)
    return p


def peak(path):
    try:
        with open(path, "rb") as f:
            samples = array.array("f")
            data = f.read()
            samples.frombytes(data[:len(data) // 4 * 4])
    except OSError:
        return 0.0
    return max((abs(x) for x in samples), default=0.0)


def tone(path):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(array.array("h", (int(8000 * math.sin(2 * math.pi * 440 * i / RATE)) for i in range(RATE * 2))).tobytes())


def heard_when(env, tmp, sinks, action, seconds=4):
    """The peak on each of `sinks` while `action` runs (recorded for `seconds`)."""
    files = {s: "%s/%s.raw" % (tmp, s) for s in sinks}
    recs = [record(env, s, files[s], seconds) for s in sinks]
    time.sleep(1.0)
    action()
    for r in recs:
        try:
            r.wait(timeout=seconds + 2)
        except subprocess.TimeoutExpired:
            r.kill()
    return {s: peak(files[s]) for s in sinks}


def scenario(env, tmp, title, source, copy, token, wait):
    print("-- " + title)
    started = run_copies(env, source, copy, token, wait)
    tone_path = tmp + "/tone.wav"
    tone(tone_path)
    music = heard_when(env, tmp, [source, copy], lambda: subprocess.run(["pw-cat", "--playback", "--target", source, tone_path], env=env, timeout=10,
                                                                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    for p in started:
        stop(p)
    time.sleep(0.5)
    return music


def main():
    tmp = tempfile.mkdtemp(prefix="orbit-graph-")
    env = environment(tmp)
    try:
        start_graph(env)
        for name in (WIRED, BLUE):
            make_sink(env, name)
        time.sleep(1)

        for title, wait in (("wired source, no wait, Bluetooth copy", 0), ("wired source with a 150 ms wait, Bluetooth copy", 150)):
            m = scenario(env, tmp, title, WIRED, BLUE, TOKEN, wait)
            check(title + ": the copied sound still reaches the copy", m[BLUE] > 0.1)
            check(title + ": the played sound still reaches the source", m[WIRED] > 0.1)
    finally:
        for p in reversed(procs):
            stop(p)
        shutil.rmtree(tmp, ignore_errors=True)
    print("all passed" if not failures else "%d failed" % len(failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
