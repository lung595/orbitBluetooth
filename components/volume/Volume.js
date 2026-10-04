.pragma library

// Pure logic of the volume tick (CardVolume.qml), tested in tests/*.test.js.

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
