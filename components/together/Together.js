.pragma library
.import "../common/Address.js" as Address
.import "../volume/Route.js" as Route

// Pure logic of Listen together (D254, D277): the same sound on two Bluetooth
// outputs at once. Who may take part, which of the two the sound is taken
// from, and the one pw-loopback that copies it. Tested by tests/together.test.js.
//
// The copy is a pw-loopback (run through Route.loopbackArgs, so it dies with
// the shell) from the monitor of the output in use to the other output.
// Both ends are passive and never fall back to another sink: nothing is
// opened when nothing plays, and a member whose link is gone (suspended, or
// taken by a phone on a multipoint headset) is simply picked up again when
// its output comes back (D279). Nothing is written to DMS or WirePlumber and
// the default output is never changed.

var MAX_DELAY_MS = 500;

// Node names Orbit gives the two ends of the copy
var NAME = "orbit_together";

// "AA:BB:CC:DD:EE:FF" -> the address, or "" when it is anything else
function address(text) {
    return Address.colon(typeof text === "string" && text.length <= 17 ? text : "");
}

// A headset link made for calls (HSP/HFP) is mono and narrow: not worth sharing.
// `profile` is the sink's "api.bluez5.profile" property.
function inCall(profile) {
    return /head-?unit|hfp|hsp/i.test(String(profile || ""));
}

// Why two devices cannot listen together, or null when they can.
// `known(address)` gives { connected, sink, profile } for a device Orbit
// sees (sink is its output's node name, "" while it has none), or null.
// -> { why, address } with why in: "bad-address", "same", "not-connected",
// "no-audio", "in-call"
function refusal(first, second, known) {
    const a = address(first), b = address(second);
    if (!a || !b)
        return { "why": "bad-address", "address": "" };
    if (a === b)
        return { "why": "same", "address": a };
    for (const who of [a, b]) {
        const d = known(who);
        if (!d || !d.connected)
            return { "why": "not-connected", "address": who };
        if (!d.sink || !Route.isDeviceSink(d.sink))
            return { "why": "no-audio", "address": who };
        if (inCall(d.profile))
            return { "why": "in-call", "address": who };
    }
    return null;
}

// Which member the sound is taken from: the one that is the current output
// (its sink, or Orbit's PC-level filter in front of it), else the first.
// `sound(address)` gives { sink, pc } node names ("" when none).
// -> { source, other, capture, playback }: the capture is the PC-level
// filter when the source has one (so this PC's level reaches both), else its
// sink; the playback is the other member's own sink, where WirePlumber puts
// that member's filter in front, if it has one.
function plan(first, second, sound, defaultSink) {
    const a = address(first), b = address(second);
    const inUse = who => {
        const s = sound(who);
        return !!defaultSink && !!s && (s.sink === defaultSink || s.pc === defaultSink);
    };
    const source = !inUse(a) && inUse(b) ? b : a;
    const other = source === a ? b : a;
    const from = sound(source), to = sound(other);
    return {
        "source": source,
        "other": other,
        "capture": from && (from.pc || from.sink) || "",
        "playback": to && to.sink || ""
    };
}

// A delay (ms) for the copy, 0..500, "" for none. Only the copy can wait, so
// it is the way to line up two outputs of different latency (Bluetooth codecs).
function delayArg(ms) {
    const n = Math.round(Number(ms));
    return n > 0 ? (Math.min(MAX_DELAY_MS, n) / 1000).toFixed(3) : "";
}

function cleanDelay(ms) {
    const n = Math.round(Number(ms));
    return n > 0 ? Math.min(MAX_DELAY_MS, n) : 0;
}

// The command that copies the sound, or null when a node name is not one of
// Orbit's or BlueZ's (value 11): the capture is a device output or an Orbit
// PC-level filter, the playback a device output.
function args(p, delayMs) {
    if (!p || !(Route.isVirtual(p.capture) || Route.isDeviceSink(p.capture)) || !Route.isDeviceSink(p.playback))
        return null;
    const stream = " node.passive=true node.dont-fallback=true";
    const capture = "node.name=" + NAME + "_in target.object=" + p.capture + " stream.capture.sink=true" + stream;
    const playback = "node.name=" + NAME + "_out target.object=" + p.playback + stream;
    return Route.loopbackArgs(capture, playback, delayArg(delayMs));
}

// What `togetherStatus` says (IPC)
function status(session) {
    return JSON.stringify({
        "active": !!session,
        "first": session ? session.first : "",
        "second": session ? session.second : "",
        "from": session ? session.source : "",
        "delayMs": session ? session.delayMs : 0
    });
}
