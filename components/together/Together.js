.pragma library
.import "../common/Address.js" as Address
.import "../volume/Route.js" as Route

// Pure logic of Listen together (D254, D277): the same sound on several
// Bluetooth outputs at once. Who may take part, which member the sound is
// taken from, and the pw-loopback that copies it to each of the others.
// Tested by tests/together.test.js.
//
// A session is a list of 2 to MAX_MEMBERS outputs ("members", in the order
// they joined). The sound is taken from one of them (the source) and copied
// to every other by its own pw-loopback, run through Route.loopbackArgs so
// that it dies with the shell. Both ends of a copy are passive and never fall
// back to another sink: nothing is opened when nothing plays, so a member's
// output goes idle and then suspends as it always did, which is what lets a
// multipoint headset hand its link to a phone (D279). A member whose output
// is away is still a member: its copy is simply stopped, and started again
// when the output comes back. Nothing is written to DMS or WirePlumber and
// the default output is never changed.

// How many outputs can listen together. Each one beyond the source costs one
// small process, and a half circle holds four arcs a finger can still hit.
var MAX_MEMBERS = 4;
var MAX_DELAY_MS = 500;

// Node names Orbit gives the two ends of a copy, followed by the member's key
var NAME = "orbit_together_";

// "AA:BB:CC:DD:EE:FF" -> the address, or "" when it is anything else
function address(text) {
    return Address.colon(typeof text === "string" && text.length <= 17 ? text : "");
}

// A headset link made for calls (HSP/HFP) is mono and narrow: not worth sharing.
// `profile` is the sink's "api.bluez5.profile" property.
function inCall(profile) {
    return /head-?unit|hfp|hsp/i.test(String(profile || ""));
}

// --- Who may take part -------------------------------------------------------------
// `known(address)` gives { connected, sink, profile } for a device Orbit sees
// (sink is its output's node name, "" while it has none), or null. Every
// refusal is { why, address }; why is one of "bad-address", "same",
// "too-few", "too-many", "already", "not-connected", "no-audio", "in-call".

// One device that is to take part: connected, with a Bluetooth output, not in
// its call profile. null when it can.
function memberRefusal(who, known) {
    const d = known(who);
    if (!d || !d.connected)
        return { "why": "not-connected", "address": who };
    if (!d.sink || !Route.isDeviceSink(d.sink))
        return { "why": "no-audio", "address": who };
    if (inCall(d.profile))
        return { "why": "in-call", "address": who };
    return null;
}

// The addresses of `list` in order, without a repeat; null when one is not
// an address (the first refusal is then { bad-address })
function clean(list) {
    if (!Array.isArray(list) || list.length > 16)
        return null;
    const out = [];
    for (const item of list) {
        const a = address(item);
        if (!a)
            return null;
        out.push(a);
    }
    return out;
}

// Why these devices cannot start listening together, or null when they can
function refusal(list, known) {
    const all = clean(list);
    if (!all)
        return { "why": "bad-address", "address": "" };
    const seen = {};
    for (const a of all) {
        if (seen[a])
            return { "why": "same", "address": a };
        seen[a] = true;
    }
    if (all.length < 2)
        return { "why": "too-few", "address": "" };
    if (all.length > MAX_MEMBERS)
        return { "why": "too-many", "address": "" };
    for (const a of all) {
        const r = memberRefusal(a, known);
        if (r)
            return r;
    }
    return null;
}

// Why `newcomers` cannot join the session of `members`, or null. Only the
// newcomers are checked: a member whose output is away (a multipoint headset
// playing for its phone) stays a member (D279).
function joinRefusal(members, newcomers, known) {
    const all = clean(newcomers);
    if (!all || !all.length)
        return { "why": "bad-address", "address": "" };
    const next = members.slice();
    for (const a of all) {
        if (next.indexOf(a) >= 0)
            return { "why": members.indexOf(a) >= 0 ? "already" : "same", "address": a };
        next.push(a);
    }
    if (next.length > MAX_MEMBERS)
        return { "why": "too-many", "address": "" };
    for (const a of all) {
        const r = memberRefusal(a, known);
        if (r)
            return r;
    }
    return null;
}

// The members after a drop of `first` onto `second` (either order): who is
// already in comes first, then the newcomers in the order given
function merge(members, first, second) {
    const out = members.slice();
    const pair = members.indexOf(address(first)) < 0 && members.indexOf(address(second)) >= 0 ? [second, first] : [first, second];
    for (const item of pair) {
        const a = address(item);
        if (a && out.indexOf(a) < 0)
            out.push(a);
    }
    return out;
}

// The members after `who` left
function without(members, who) {
    return members.filter(a => a !== address(who));
}

// --- Where the sound comes from ----------------------------------------------------------
// `sound(address)` gives { sink, pc, profile }: node names ("" when none),
// null for a device Orbit does not see. A member can be copied to when it has
// a Bluetooth output that is not in its call profile.
function present(s) {
    return !!s && Route.isDeviceSink(s.sink) && !inCall(s.profile);
}

// The member the sound is taken from: the one that is the current output
// (its sink, or Orbit's PC-level filter in front of it), else the first one
// with an output, else the first
function source(members, sound, defaultSink) {
    const inUse = who => {
        const s = sound(who);
        return !!defaultSink && !!s && (s.sink === defaultSink || s.pc === defaultSink);
    };
    return members.find(a => present(sound(a)) && inUse(a)) || members.find(a => present(sound(a))) || members[0] || "";
}

// What each copy takes and gives: { source, taps: [{ member, capture,
// playback }] }, one tap per other member whose output is there. The capture
// is the source's PC-level filter when it has one (its monitor is the sound
// before this PC's level, which every member applies itself: the level is
// shared, D254), else its sink; the playback is the member's own sink, where
// WirePlumber puts that member's filter in front, if it has one.
function plan(members, sound, defaultSink) {
    const from = source(members, sound, defaultSink);
    const s = from ? sound(from) : null;
    const capture = s && present(s) ? s.pc || s.sink : "";
    const taps = [];
    if (capture)
        for (const who of members) {
            const t = sound(who);
            if (who !== from && present(t))
                taps.push({ "member": who, "capture": capture, "playback": t.sink });
        }
    return { "source": from, "taps": taps };
}

// --- The copies ---------------------------------------------------------------------------
// A delay (ms) for a copy, 0..500, "" for none. Only a copy can wait, so it
// is the way to line up outputs of different latency (Bluetooth codecs).
function delayArg(ms) {
    const n = Math.round(Number(ms));
    return n > 0 ? (Math.min(MAX_DELAY_MS, n) / 1000).toFixed(3) : "";
}

function cleanDelay(ms) {
    const n = Math.round(Number(ms));
    return n > 0 ? Math.min(MAX_DELAY_MS, n) : 0;
}

// The command of one copy, or null when a node name is not one of Orbit's or
// BlueZ's (value 11): the capture is a device output or an Orbit PC-level
// filter, the playback a device output.
function args(tap, delayMs) {
    const key = tap ? Address.key(tap.member) : "";
    if (!key || !(Route.isVirtual(tap.capture) || Route.isDeviceSink(tap.capture)) || !Route.isDeviceSink(tap.playback))
        return null;
    const stream = " node.passive=true node.dont-fallback=true";
    const capture = "node.name=" + NAME + key + "_in target.object=" + tap.capture + " stream.capture.sink=true" + stream;
    const playback = "node.name=" + NAME + key + "_out target.object=" + tap.playback + stream;
    return Route.loopbackArgs(capture, playback, delayArg(delayMs));
}

// The copies to run: [{ key (the member), command }] for a plan and the
// delays of the members ({ address: ms })
function commands(p, delays) {
    const out = [];
    for (const tap of p ? p.taps : []) {
        const command = args(tap, delays ? delays[tap.member] : 0);
        if (command)
            out.push({ "key": tap.member, "command": command });
    }
    return out;
}

// What to stop and what to start to go from the copies running
// ({ key: command }) to the wanted ones: a copy whose command changed is
// stopped and started again, one that did not is left alone, so a newcomer
// never cuts the others.
function diff(running, wanted) {
    const keep = {};
    const start = [];
    for (const w of wanted) {
        keep[w.key] = true;
        if (!running[w.key] || JSON.stringify(running[w.key]) !== JSON.stringify(w.command))
            start.push(w);
    }
    const stop = Object.keys(running).filter(k => !keep[k] || start.some(w => w.key === k));
    return { "stop": stop, "start": start };
}

// The delays of `delays` ({ address: ms }) that belong to a member of
// `members`: a member that left takes its delay with it
function prune(delays, members) {
    const next = {};
    for (const m of members)
        if (delays && delays[m])
            next[m] = delays[m];
    return next;
}

// The delays after `ms` was asked for `who` (a member of `members`)
function withDelay(delays, members, who, ms) {
    const a = address(who);
    const next = prune(delays, members);
    if (a && members.indexOf(a) >= 0) {
        const n = cleanDelay(ms);
        if (n)
            next[a] = n;
        else
            delete next[a];
    }
    return next;
}

// The addresses of a text from the command line ("A,B C"): split on commas and
// spaces. [] for anything too long to be a list of Bluetooth addresses.
function parseList(text) {
    const s = typeof text === "string" && text.length <= 200 ? text.trim() : "";
    return s ? s.split(/[\s,]+/) : [];
}

// What `togetherStatus` says (IPC): the members in order, the one the sound
// is taken from and each member's extra delay
function status(session) {
    return JSON.stringify({
        "active": !!session,
        "members": session ? session.members : [],
        "from": session ? session.source : "",
        "delaysMs": session ? session.delays : {}
    });
}
