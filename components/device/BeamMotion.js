.pragma library

// Where the moving parts of a charging beam are at a given moment. Every
// style reads the scene's 30 Hz effects clock through these functions and
// holds no clock of its own; with Reduce motion (not running) each one answers
// its still frame. Pure; tested by tests/beamStyle.test.js.

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

// Chain: a lit window (30 % of the link) runs to the device in 1.2 s, then the
// link rests for 0.3 s before the next one
var CHAIN_TRAVEL = 1.2;
var CHAIN_GAP = 0.3;
var CHAIN_WINDOW = 0.3;
var CHAIN_STILL = [0.35, 0.65];   // the window frozen around the middle of the link

function clamp01(x) {
    return Math.max(0, Math.min(1, x));
}

// The lit window of the Chain style as [from, to], shares of the link (0..1).
// It enters at the host end and leaves at the device end, so it is short and
// growing, then whole, then short and shrinking
function chainWindow(time, running, offset) {
    if (!running)
        return CHAIN_STILL;
    const cycle = CHAIN_TRAVEL + CHAIN_GAP;
    const t = fract((time - offset) / cycle) * cycle;
    const head = Math.min(1, t / CHAIN_TRAVEL) * (1 + CHAIN_WINDOW);
    return [clamp01(head - CHAIN_WINDOW), clamp01(head)];
}

// Horizon: grains fall along the bent path in 1.8 s, a knot turns round the
// device's ring once per 3 s. Both start where their still frame is.
var HORIZON_FALL = 1.8;
var HORIZON_TURN = 3;
var HORIZON_STILL_GRAIN = 0.72;
var HORIZON_STILL_KNOT = 0.9;     // rad

// How far (0..1) the lead grain is along the path, before the fall's acceleration
function grainFront(time, running, offset) {
    return running ? fract((time - offset) / HORIZON_FALL + HORIZON_STILL_GRAIN) : HORIZON_STILL_GRAIN;
}

// Where the knot is on its ring (rad)
function knotAngle(time, running, offset) {
    return running ? HORIZON_STILL_KNOT + (time - offset) / HORIZON_TURN * 2 * Math.PI : HORIZON_STILL_KNOT;
}
