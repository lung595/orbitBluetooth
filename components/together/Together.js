.pragma library
.import "../common/Address.js" as Address
.import "../volume/Route.js" as Route
.import "Member.js" as Member

// Pure logic of Listen together (D254, D277, D298): the same sound on several
// outputs at once, Bluetooth or wired. Who may take part, which member the
// sound is taken from, and the pw-loopback that copies it to each of the
// others. Tested by tests/together.test.js.
//
// A session is a list of 2 to MAX_MEMBERS outputs ("members", in the order
// they joined), each one a token of Member.js: a Bluetooth address or the
// node name of a wired (ALSA) output. A session can mix both. The sound is taken from one of them (the source) and copied
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
// The longest wait of a copy or of a wired source's filter: one number for
// every pw-loopback Orbit runs (Route.js)
var MAX_DELAY_MS = Route.MAX_DELAY_MS;

// What the filter of a wired source is called in the list of processes: never
// the token of a member (Member.js), so it cannot be taken for a copy
var FILTER_KEY = "wired-source-filter";

// Node names Orbit gives the two ends of a copy, followed by the member's key
var NAME = "orbit_together_";

// The longest text of a command line that can hold the members of a session
var MAX_LIST_LENGTH = MAX_MEMBERS * (Member.MAX_LENGTH + 1);

// "AA:BB:CC:DD:EE:FF" -> the address, or "" when it is anything else (a wired
// output is not an address: see member)
function address(text) {
    return Address.colon(typeof text === "string" && text.length <= 17 ? text : "");
}

// A member of a session, Bluetooth or wired: its token, or "" for anything
// else. The one way every function below reads a member.
function member(text) {
    return Member.clean(text);
}

// A headset link made for calls (HSP/HFP) is mono and narrow: not worth sharing.
// `profile` is the sink's "api.bluez5.profile" property.
function inCall(profile) {
    return /head-?unit|hfp|hsp/i.test(String(profile || ""));
}

// --- Who may take part -------------------------------------------------------------
// `known(member)` gives { connected, sink, profile } for an output Orbit sees
// (sink is its output's node name, "" while it has none), or null. For a wired
// output "connected" means plugged in, and a call profile never applies.
// Every refusal is { why, address } (address is the member's token); why is
// one of "bad-address" (also for a name that is not a wired output's), "same",
// "too-few", "too-many", "already", "not-connected", "no-audio", "in-call".

// One output that is to take part: there, with an output of its own kind (a
// BlueZ sink for a Bluetooth device, an ALSA one for a wired output), and a
// Bluetooth device not in its call profile. null when it can.
function memberRefusal(who, known) {
    const d = known(who);
    if (!d || !d.connected)
        return { "why": "not-connected", "address": who };
    if (!d.sink || !fits(who, d.sink))
        return { "why": "no-audio", "address": who };
    if (!Member.isWired(who) && inCall(d.profile))
        return { "why": "in-call", "address": who };
    return null;
}

// Whether `sink` is the kind of output a member is: a BlueZ output for a
// Bluetooth device, an ALSA one for a wired output
function fits(who, sink) {
    return Member.isWired(who) ? Member.isWired(sink) : Route.isDeviceSink(sink);
}

// The members of `list` in order, without a repeat; null when one is not a
// member (the first refusal is then { bad-address })
function clean(list) {
    if (!Array.isArray(list) || list.length > 16)
        return null;
    const out = [];
    for (const item of list) {
        const a = member(item);
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
    const pair = members.indexOf(member(first)) < 0 && members.indexOf(member(second)) >= 0 ? [second, first] : [first, second];
    for (const item of pair) {
        const a = member(item);
        if (a && out.indexOf(a) < 0)
            out.push(a);
    }
    return out;
}

// The members after `who` left
function without(members, who) {
    return members.filter(a => a !== member(who));
}

// --- Where the sound comes from ----------------------------------------------------------
// `sound(member)` gives { sink, pc, profile }: node names ("" when none),
// null for an output Orbit does not see. `pc` is the filter in front of the
// output: the PC-level one of a Bluetooth output, or the source filter of a
// wired source (Route.wiredFilterArgs), once it exists. A member can be copied
// to when it has an output of its own kind (see fits), and a Bluetooth one is
// not in its call profile.
function present(who, s) {
    return !!s && fits(who, s.sink) && (Member.isWired(who) || !inCall(s.profile));
}

// The member the sound is taken from: the one that is the current output
// (its sink, or Orbit's PC-level filter in front of it), else the first one
// with an output, else the first
function source(members, sound, defaultSink) {
    const inUse = who => {
        const s = sound(who);
        return !!defaultSink && !!s && (s.sink === defaultSink || s.pc === defaultSink);
    };
    const there = a => present(a, sound(a));
    return members.find(a => there(a) && inUse(a)) || members.find(there) || members[0] || "";
}

// What each copy takes and gives: { source, taps: [{ member, capture,
// playback }] }, one tap per other member whose output is there. The capture
// is the source's PC-level filter when it has one (its monitor is the sound
// before this PC's level, which every member applies itself: the level is
// shared, D254), else its sink (a wired source has a filter all through the
// session, and its copies read that filter's monitor, the sound before the
// wait, once it exists; only until then do they read its sink); the playback
// is the member's own sink, where WirePlumber puts that member's filter in
// front, if it has one.
function plan(members, sound, defaultSink) {
    const from = source(members, sound, defaultSink);
    const s = from ? sound(from) : null;
    const capture = s && present(from, s) ? s.pc || s.sink : "";
    const taps = [];
    if (capture)
        for (const who of members) {
            const t = sound(who);
            if (who !== from && present(who, t))
                taps.push({ "member": who, "capture": capture, "playback": t.sink });
        }
    return { "source": from, "taps": taps };
}

// --- The copies ---------------------------------------------------------------------------
// A delay (ms) for a copy, 0..MAX_DELAY_MS, "" for none. A copy can wait, and
// so can a wired source through its filter (filterCommand): that is the way
// to line up outputs of different latency (Bluetooth codecs).
function cleanDelay(ms) {
    const n = Math.round(Number(ms));
    return n > 0 ? Math.min(MAX_DELAY_MS, n) : 0;
}

function delayArg(ms) {
    const n = cleanDelay(ms);
    return n > 0 ? (n / 1000).toFixed(3) : "";
}

// A node name a copy may read from or play to: a Bluetooth output or a wired
// one, checked as a member's sink is (value 11)
function isOutput(name) {
    return Route.isDeviceSink(name) || Member.isWired(name);
}

// A node name a copy may read from: an output, or one of Orbit's filters (the
// PC-level one of a Bluetooth output, the source one of a wired source)
function isSource(name) {
    return isOutput(name) || Route.isVirtual(name) || Route.isWiredFilter(name);
}

// The command of one copy, or null when a node name is not one of Orbit's,
// BlueZ's or a valid ALSA output's (value 11): the capture is an output or an
// Orbit filter, the playback an output, and never the same one (a copy of an
// output to itself would feed back).
function args(tap, delayMs) {
    const key = tap ? Member.key(tap.member) : "";
    if (!key || !isSource(tap.capture) || !isOutput(tap.playback) || tap.capture === tap.playback)
        return null;
    const stream = " node.passive=true node.dont-fallback=true";
    const capture = "node.name=" + NAME + key + "_in target.object=" + tap.capture + " stream.capture.sink=true" + stream;
    const playback = "node.name=" + NAME + key + "_out target.object=" + tap.playback + stream;
    return Route.loopbackArgs(capture, playback, delayArg(delayMs));
}

// The command of the filter in front of a wired source, or null when the
// source is not wired (`ms` is how long it waits, possibly nothing: the copies
// still read the filter and not the sink, or the volume tick played in the
// sink would sound in them)
function filterCommand(p, ms) {
    return p && Member.isWired(p.source) ? Route.wiredFilterArgs(p.source, delayArg(ms)) : null;
}

// The processes to run: [{ key, command }], the filter of a wired source
// first (key FILTER_KEY), then one copy per tap (key: the member), for a plan,
// the delays of the members ({ member: ms }) and the wait of the wired source (ms)
function commands(p, delays, sourceWaitMs) {
    const out = [];
    const filter = filterCommand(p, sourceWaitMs);
    if (filter)
        out.push({ "key": FILTER_KEY, "command": filter });
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

// The delays of `delays` ({ member: ms }) that belong to a member of
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
    const a = member(who);
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

// The members of a text from the command line ("A,B C"): split on commas and
// spaces. [] for anything too long to be a list of members.
function parseList(text) {
    const s = typeof text === "string" && text.length <= MAX_LIST_LENGTH ? text.trim() : "";
    return s ? s.split(/[\s,]+/) : [];
}

// What `togetherStatus` says (IPC): the members in order, the one the sound
// is taken from, each member's extra delay, and what each one adds before it
// is heard (the figures a wired copy's automatic wait is made from: a wired
// output with none counts for 0, see Delay.latenciesOf)
function status(session) {
    return JSON.stringify({
        "active": !!session,
        "members": session ? session.members : [],
        "from": session ? session.source : "",
        "delaysMs": session ? session.delays : {},
        "latenciesMs": session && session.latencies ? session.latencies : {}
    });
}
