.pragma library

// Geometry of the Horizon charging beam: light bent by the device's gravity
// (a quadratic arc from the host to the device), grains falling along it, and a
// thin ring seen almost edge-on round the device with a knot orbiting it.
// Only places, sizes and alphas; where the clock puts things is BeamMotion.js.
// Pure; tested by tests/beamStyle.test.js.

var BEND_SHARE = 0.14;    // of the link's length...
var BEND_MAX = 26;        // ...and never more than this many px
var CONTROL_AT = 0.55;    // where along the link the arc bends most
var GRAINS = 6;
var TAIL = 8;             // dots behind the knot
var TAIL_STEP = 0.0875;   // rad between two of them (40 degrees in all)
// The ring never outsizes the scene's black hole (D375), nor does anything lit
// outshine its resting line (alpha 0.7)
var RING_SCALE = 1.3;
var RING_TILT = 0.24;     // vertical share of the ring
var RING_ROTATION = -0.12; // rad
var CAP = 0.7;

function bend(len) {
    return Math.min(BEND_MAX, len * BEND_SHARE);
}

// A point of the arc, u in 0..1; the arc bends upward (negative y)
function pointAt(len, u) {
    return {
        x: 2 * (1 - u) * u * len * CONTROL_AT + u * u * len,
        y: -2 * (1 - u) * u * bend(len)
    };
}

// Control point of the part of the arc between u = a and u = b (it is a
// quadratic Bezier, so a sub-curve is one too; the host end is the origin, so
// its weight drops out); draws the arc in several colours
function controlAt(len, a, b) {
    const c = { x: len * CONTROL_AT, y: -bend(len) };
    const w1 = a * (1 - b) + b * (1 - a);
    const w2 = a * b;
    return { x: c.x * w1 + len * w2, y: c.y * w1 };
}

// Grain k (0 = the lead) when the lead is at `front`: the fall accelerates
// (u = front squared), the others trail by 2 % of the arc each; they fade in
// at the host and out at the device and shrink along the trail
function grain(len, front, k) {
    const u = Math.max(0, front * front - k * 0.02);
    const p = pointAt(len, u);
    return {
        x: p.x,
        y: p.y,
        r: 1.8 - k * 0.2,
        alpha: (1 - k / GRAINS) * Math.min(1, (1 - u) * 8, u * 20 + 0.2)
    };
}

// The ring's radius for a device of radius `deviceRadius`
function ringRadius(deviceRadius) {
    return deviceRadius * RING_SCALE;
}

// A point of the ring at `angle` (rad), before the ring's own rotation
function ringPoint(radius, angle) {
    return { x: radius * Math.cos(angle), y: radius * RING_TILT * Math.sin(angle) };
}

// The knot is lit fully on the near side of the ring and half on the far side
function knotAlpha(angle) {
    return Math.sin(angle) > 0 ? CAP : CAP / 2;
}

// Dot k of the knot's tail: where it is and how lit (fading to nothing)
function tailAt(radius, angle, k) {
    const a = angle - (k + 0.5) * TAIL_STEP;
    const p = ringPoint(radius, a);
    return { x: p.x, y: p.y, alpha: CAP * (1 - k / TAIL) };
}
