.pragma library
.import "Member.js" as Member
.import "Together.js" as Together

// The automatic delay of Listen together (D298): a wired output answers in a
// few milliseconds, a Bluetooth one a good deal later, so the wired copy waits
// for what the Bluetooth output adds. Only a wired copy ever waits: a
// Bluetooth output is never delayed, so it never grows more latency than its
// codec gives it. Latencies are given by the caller (what PipeWire or BlueZ
// report); none is written here. Pure logic, tested by tests/delay.test.js.

// How far the user can nudge the automatic delay either way (ms), to match
// what the figures cannot know (a speaker's own processing, a TV)
var MAX_FINE_MS = 100;

// A latency the caller knows: a finite number of milliseconds, not negative
function isLatency(ms) {
    return typeof ms === "number" && isFinite(ms) && ms >= 0;
}

// The correction asked by the user, 0 for anything that is not a number, kept
// within +-MAX_FINE_MS
function cleanFine(ms) {
    return typeof ms === "number" && isFinite(ms) ? Math.max(-MAX_FINE_MS, Math.min(MAX_FINE_MS, ms)) : 0;
}

// What a copy must wait (ms, a whole number, 0..Together.MAX_DELAY_MS): the
// time the source takes to be heard more than the member does, plus the
// user's correction. 0 when either latency is not known: no figure is made up,
// so a correction has nothing to correct then (the member's own manual delay
// is still there).
function autoDelayMs(sourceLatencyMs, memberLatencyMs, fineMs) {
    if (!isLatency(sourceLatencyMs) || !isLatency(memberLatencyMs))
        return 0;
    return Together.cleanDelay(Math.max(0, sourceLatencyMs - memberLatencyMs) + cleanFine(fineMs));
}

// The automatic delays of the copies of a plan (Together.plan): { member: ms },
// for the wired members only and only those that wait. `latencies` is
// { member: ms } for the members the caller knows the latency of, the
// source's included.
function delaysFor(plan, latencies, fineMs) {
    const out = {};
    if (!plan || !Array.isArray(plan.taps) || !latencies)
        return out;
    for (const tap of plan.taps) {
        if (!Member.isWired(tap.member))
            continue;
        const ms = autoDelayMs(latencies[plan.source], latencies[tap.member], fineMs);
        if (ms > 0)
            out[tap.member] = ms;
    }
    return out;
}
