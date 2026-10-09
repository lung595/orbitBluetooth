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

// How many steps a change of level crosses: a tick is due when it crosses one
// (a jump of 30 % is still ONE tick, heard live, never a run replayed late)
function stepsCrossed(before, after, size) {
    return Math.abs(step(after, size) - step(before, size));
}

// A tick plays at most once per MIN_GAP_MS (40 a second): faster would blur into
// a buzz. A tick that comes sooner is dropped, never kept for later, so the
// sound always follows the hand and stops with it
var MIN_GAP_MS = 25;

// Whether a tick may play at `now`, the last one having played at `last` (ms)
function due(now, last) {
    return !(now >= last) || now - last >= MIN_GAP_MS;
}

// The tick is quiet by itself; what makes it crackle is a loud output.
// Below TICK_KNEE of the output's level it plays in full; above, its gain
// falls as TICK_KNEE / level, so what comes out stays what it is at the knee
// instead of growing with the level until it saturates. Chosen by ear on the
// shipped sound (peak 0.3 of full scale), so at 100 % it is 0.6 of itself.
var TICK_KNEE = 0.6;

// The gain, 0..1, of a tick in an output whose level is `level`
function tickGain(level) {
    const v = clamp(level);
    return v <= TICK_KNEE ? 1 : TICK_KNEE / v;
}

// A silent output (0 %) has nothing to tick: no player is started for it
function audible(level) {
    return clamp(level) > 0;
}

// How long a player stays open after the last tick: a stream kept for ever
// would hold a Bluetooth output awake, one closed too soon costs a start for
// the next run of ticks
var IDLE_MS = 2000;

// The outputs a tick plays in, from `entries` ({name, level, bypass}: a node a
// change reached and the level it now has): only plain names, each once, silent
// outputs left out, MAX_TICKS at most; each with the gain its level allows.
// `bypass` says the tick goes round the node that holds the level (straight to
// the device behind a PC-level filter, Route.tickOutput), which then no longer
// scales it: the level is applied here instead, so it sounds the same.
function tickTargets(entries) {
    const out = [];
    for (const e of entries || [])
        if (e && validSink(e.name) && audible(e.level) && !out.some(t => t.name === e.name))
            out.push({
                "name": e.name,
                "gain": e.bypass ? tickGain(e.level) * clamp(e.level) : tickGain(e.level)
            });
    return out.slice(0, MAX_TICKS);
}

// The player slot of each of `names` (the sinks a tick plays in): the slot
// already holding that sink, else a free one, else one holding a sink not
// wanted now. `held` is the sink each slot holds ("" for none). Neighbouring
// ticks of the same outputs thus keep their players instead of swapping them.
function slotsFor(held, names) {
    const taken = new Set();
    const slots = names.map(name => {
        const i = held.indexOf(name);
        if (i >= 0)
            taken.add(i);
        return i;
    });
    return slots.map((slot, k) => {
        if (slot >= 0)
            return slot;
        let free = -1;
        for (let i = 0; i < held.length; i++) {
            if (taken.has(i))
                continue;
            if (held[i] === "") {
                free = i;
                break;
            }
            if (free < 0 && names.indexOf(held[i]) < 0)
                free = i;
        }
        if (free >= 0)
            taken.add(free);
        return free;
    });
}
