.pragma library

// Pure logic of the volume tick (VolumeTick.qml), tested in tests/*.test.js.

// The level a tick stands for, from the setting "Tick every 1 % / 5 %" (a
// number, or the string the settings page stores): 1 % unless it says 5
function stepSize(setting) {
    return String(setting) === "5" ? 0.05 : 0.01;
}

function clamp(v) {
    return Math.max(0, Math.min(1, Number(v) || 0));
}

// Index of the step a level falls in: a tick plays for each one crossed
function step(v, size) {
    return Math.round(clamp(v) / size);
}

// Only a plain node name is ever passed to pw-play (value 11)
function validSink(name) {
    return typeof name === "string" && name.length > 0 && name.length <= 128 && /^[A-Za-z0-9_.:-]+$/.test(name);
}

// A tick plays in at most this many outputs at once: a group has four at most
var MAX_TICKS = 4;

// How many steps a change of level crosses, so how many ticks it is worth:
// a jump of 30 % is 30 of them, not one
function stepsCrossed(before, after, size) {
    return Math.abs(step(after, size) - step(before, size));
}

// Ticks are played one every TICK_MS (about 40 a second): faster would blur
// into a buzz, and a jump must be heard as a run, not as a burst at once
var TICK_MS = 25;

// Ticks waiting for their turn never exceed this: a full sweep of the dial
// (100 steps) is heard for 300 ms at most instead of 2.5 s after the hand
// stopped
var MAX_QUEUE = 12;

// The ticks still to play once a change that crosses `crossed` steps is added
function queued(pending, crossed) {
    return Math.min(MAX_QUEUE, Math.max(0, pending) + crossed);
}

// How long a player stays open after the last tick: a stream kept for ever
// would hold a Bluetooth output awake, one closed too soon costs a start for
// the next run of ticks
var IDLE_MS = 2000;

// The sinks a tick plays in, from the node names a change reached: only plain
// names, each once, MAX_TICKS at most
function tickSinks(names) {
    const out = [];
    for (const name of names || [])
        if (validSink(name) && out.indexOf(name) < 0)
            out.push(name);
    return out.slice(0, MAX_TICKS);
}
