.pragma library

// Pure logic of the volume tick (VolumeTick.qml), tested in tests/*.test.js.

// One step of the tick: a soft sound plays each time the level crosses one
var stepSize = 0.05;

function clamp(v) {
    return Math.max(0, Math.min(1, Number(v) || 0));
}

// Index of the 5 % step a level falls in: a tick plays when it changes
function step(v) {
    return Math.round(clamp(v) / stepSize);
}

// Only a plain node name is ever passed to pw-play (value 11)
function validSink(name) {
    return typeof name === "string" && name.length > 0 && name.length <= 128 && /^[A-Za-z0-9_.:-]+$/.test(name);
}

// A tick plays in at most this many outputs at once: a group has four at most
var MAX_TICKS = 4;

// Whether a change of level crosses a step, so that it is worth a tick
function crosses(before, after) {
    return step(before) !== step(after);
}

// The sinks a tick plays in, from the node names a change reached: only plain
// names, each once, MAX_TICKS at most
function tickSinks(names) {
    const out = [];
    for (const name of names || [])
        if (validSink(name) && out.indexOf(name) < 0)
            out.push(name);
    return out.slice(0, MAX_TICKS);
}
