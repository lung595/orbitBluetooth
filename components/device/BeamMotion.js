.pragma library

// Where the moving parts of a charging beam are at a given moment. Every
// style reads the scene's 30 Hz effects clock through these functions and
// holds no clock of its own; with Reduce motion (not running) each one answers
// its still frame. Pure; tested by tests/beamMotion.test.js.

var PULSE_PERIOD = 1.6;                    // s for a capsule to cross the link
var PULSE_STILL = [1 / 6, 1 / 2, 5 / 6];   // capsules at rest, and where the motion starts from
var PULSE_EDGE = 0.15;                     // share of the link over which a capsule fades in and out
var PHASE_STEP = 0.5;                      // s between two charging devices, so they do not pulse in unison
var PHASE_SLOTS = 4;

function fract(x) {
    return x - Math.floor(x);
}

// How far along the link (0..1) capsule `i` of the Pulse style is; `offset` (s)
// delays it
function pulseAt(time, running, i, offset) {
    return running ? fract((time - offset) / PULSE_PERIOD + PULSE_STILL[i]) : PULSE_STILL[i];
}

// A capsule is clear in the middle and fades near both ends of the link
function pulseAlpha(at) {
    return Math.max(0, Math.min(1, at / PULSE_EDGE, (1 - at) / PULSE_EDGE));
}

// A steady delay (s) for a device, from its address: the same device always
// gets the same one, a few devices charging together mostly get different ones
function deviceOffset(address) {
    let h = 0;
    const s = String(address ?? "");
    for (let k = 0; k < s.length; k++)
        h = (h * 31 + s.charCodeAt(k)) % 997;
    return (h % PHASE_SLOTS) * PHASE_STEP;
}
