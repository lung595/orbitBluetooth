.pragma library
.import "Member.js" as Member
.import "Together.js" as Together

// The automatic delay of Listen together (D298, D368): a wired output answers
// in a few milliseconds, a Bluetooth one a good deal later, and two Bluetooth
// codecs differ as much, so a copy waits for what the output the sound is
// heard on adds more than it does. A copy never waits for an output that is
// quicker than it: nothing can speed an output up, so the late one is left as
// it is. Latencies are given by the caller (what PipeWire reports); none is
// written here and none is made up. Pure logic, tested by tests/delay.test.js.

// How far the user can nudge the automatic delay either way (ms), to match
// what the figures cannot know (a speaker's own processing, a TV)
var MAX_FINE_MS = 100;
// How much one notch of the slider, or one `up` / `down` of the command line,
// moves it (ms): the settings, the command and their tests share this one
var FINE_STEP_MS = 5;

// A latency the caller knows: a finite number of milliseconds, not negative
function isLatency(ms) {
    return typeof ms === "number" && isFinite(ms) && ms >= 0;
}

// The correction asked by the user, 0 for anything that is not a number, kept
// within +-MAX_FINE_MS
function cleanFine(ms) {
    return typeof ms === "number" && isFinite(ms) ? Math.max(-MAX_FINE_MS, Math.min(MAX_FINE_MS, ms)) : 0;
}

// The correction as the settings and the command line say it, with its sign:
// "+20 ms", "−35 ms" (a true minus sign) or "0 ms"
function fineText(ms) {
    const n = Math.round(cleanFine(ms));
    return (n > 0 ? "+" : n < 0 ? "−" : "") + Math.abs(n) + " ms";
}

// The correction `dms ipc call orbitBluetooth wiredDelay <arg>` asks for, from
// the one in force: "up" / "down" (one step), "+10" / "-10" (from now), "20"
// (that wait, 0 to MAX_FINE_MS), "reset" (none) or "status" (the one in force,
// unchanged). null for anything else, so the caller says how to use it without
// echoing what it was given (value 11).
function fineFrom(arg, current) {
    const a = String(arg === undefined || arg === null ? "" : arg).trim().toLowerCase();
    if (a.length === 0 || a.length > 6)
        return null;
    const now = cleanFine(current);
    if (a === "status")
        return now;
    if (a === "reset")
        return 0;
    if (a === "up")
        return cleanFine(now + FINE_STEP_MS);
    if (a === "down")
        return cleanFine(now - FINE_STEP_MS);
    const m = /^([+-]?)([0-9]{1,3})$/.exec(a);
    if (!m)
        return null;
    const n = parseInt(m[2], 10);
    if (m[1] === "+")
        return cleanFine(now + n);
    if (m[1] === "-")
        return cleanFine(now - n);
    return n > MAX_FINE_MS ? null : n;
}

// What each member adds before it is heard (ms), { member: ms }, from the sink
// each one plays on (`sinks`, { member: node name }) and what PipeWire's graph
// reports (`graph`, AudioGraph.parseDump: { node name: { latencyMs } }). A wired
// output the graph gives no time for counts as 0: it answers within a few
// milliseconds and the user's correction covers the rest. A Bluetooth output
// with no figure is left out, never guessed (autoDelayMs then waits for nothing).
function latenciesOf(sinks, graph) {
    const out = {};
    for (const who of Object.keys(sinks || {})) {
        const known = graph && graph[sinks[who]];
        if (known && isLatency(known.latencyMs))
            out[who] = known.latencyMs;
        else if (Member.isWired(who))
            out[who] = 0;
    }
    return out;
}

// What a copy must wait (ms, a whole number, 0..Together.MAX_DELAY_MS): the
// time the source takes to be heard more than the member does, plus the
// user's correction (`fineMs`, 0 where it does not apply). 0 when either
// latency is not known: no figure is made up, so a correction has nothing to
// correct then (the member's own manual delay is still there).
function autoDelayMs(sourceLatencyMs, memberLatencyMs, fineMs) {
    if (!isLatency(sourceLatencyMs) || !isLatency(memberLatencyMs))
        return 0;
    return Together.cleanDelay(Math.max(0, sourceLatencyMs - memberLatencyMs) + cleanFine(fineMs));
}

// The automatic delays of the copies of a plan (Together.plan): { member: ms },
// only for the members that wait. `latencies` is { member: ms } for the members
// the caller knows the latency of, the source's included. The user's
// correction nudges the wired copies only: it is made for what the figures
// cannot know of a wired output (a speaker's own processing, a TV), and a
// Bluetooth output's figure is the whole of what it adds.
function delaysFor(plan, latencies, fineMs) {
    const out = {};
    if (!plan || !Array.isArray(plan.taps) || !latencies)
        return out;
    for (const tap of plan.taps) {
        const ms = autoDelayMs(latencies[plan.source], latencies[tap.member], Member.isWired(tap.member) ? fineMs : 0);
        if (ms > 0)
            out[tap.member] = ms;
    }
    return out;
}

// The members whose latency is not in `latencies`, in session order: the ones
// the automatic delay cannot line up, which keep their own timing (the caller
// says so, value 10). A wired output always has a figure (latenciesOf).
function unknownOf(members, latencies) {
    return (members || []).filter(who => !latencies || !isLatency(latencies[who]));
}

// The delay of every copy: the automatic one and the user's own (both
// { member: ms }) added, capped like any other; only the copies that wait are in
// the answer
function total(auto, manual) {
    const out = {};
    for (const who of Object.keys(auto || {}).concat(Object.keys(manual || {}))) {
        const ms = Together.cleanDelay((auto && auto[who] || 0) + (manual && manual[who] || 0));
        if (ms > 0)
            out[who] = ms;
    }
    return out;
}

// How long a wired SOURCE is heard later than it would be without Orbit,
// without the user's correction (ms): the Bluetooth copy that takes the
// longest to be heard sets it. 0 for a Bluetooth source, and when no latency
// is known.
function _sourceLag(plan, latencies) {
    let lag = 0;
    for (const tap of plan.taps)
        if (!Member.isWired(tap.member))
            lag = Math.max(lag, autoDelayMs(latencies[tap.member], latencies[plan.source], 0));
    return lag;
}

// Everything that must wait in a plan: { source, taps }. `source` is the wait
// (ms) of the wired source's filter, 0 for none: a wired source cannot be
// delayed in a copy, so its filter waits instead, and the Bluetooth outputs
// never do. `taps` is delaysFor's answer, counted from the moment the source is
// heard (a wired copy beside a delayed wired source has that wait to add, since
// the copies read the filter's monitor, the sound before the wait).
function waitsFor(plan, latencies, fineMs) {
    const none = { "source": 0, "taps": {} };
    if (!plan || !Array.isArray(plan.taps) || !latencies)
        return none;
    if (!Member.isWired(plan.source))
        return { "source": 0, "taps": delaysFor(plan, latencies, fineMs) };
    const lag = _sourceLag(plan, latencies);
    const heard = Object.assign({}, latencies);
    if (isLatency(heard[plan.source]))
        heard[plan.source] += lag;
    // A correction with no Bluetooth copy to line up with has nothing to
    // correct on the source: it moves the wired copies, as delaysFor says
    const bluetooth = plan.taps.some(t => !Member.isWired(t.member) && isLatency(latencies[t.member]));
    return {
        "source": bluetooth && isLatency(latencies[plan.source]) ? Together.cleanDelay(lag + cleanFine(fineMs)) : 0,
        "taps": delaysFor(plan, heard, fineMs)
    };
}
