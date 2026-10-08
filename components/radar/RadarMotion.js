.pragma library

// The maths of the volume radar's motion: easing and gliding, nothing else. Pure,
// so the clock (RadarClock) and the view only ask for numbers, and the same
// numbers are tested without a screen (tests/radarMotion.test.js).

var ENTRANCE = 0.45;  // seconds: the card comes in, the arcs sweep up, the small dials pop in
var STAGGER = 0.05;   // seconds between two small dials coming in
var MORPH = 0.3;      // seconds: a tapped small dial grows to the middle, the old hero takes its place
var RIPPLE = 0.35;    // seconds: the ring that leaves the mute pill
var GLIDE = 16;       // per second: how fast a drawn level follows the real one
var SNAP = 0.002;     // a glide this close to its target lands on it

function clamp(t) {
    return Math.max(0, Math.min(1, t));
}

// Ease-out cubic of `t` held to 0..1: quick at first, soft at the end
function ease(t) {
    const u = 1 - clamp(t);
    return 1 - u * u * u;
}

function mix(a, b, t) {
    return a + (b - a) * t;
}

// The eased part of the stretch [start, start + len] that `t` (seconds) has covered
function phase(t, start, len) {
    return len > 0 ? ease((t - start) / len) : (t >= start ? 1 : 0);
}

// `current` one step of `dt` seconds closer to `target`: an exponential glide, the
// same at any frame rate, that lands on the target instead of creeping to it
function follow(current, target, dt, rate) {
    if (Math.abs(target - current) <= SNAP)
        return target;
    const next = current + (target - current) * (1 - Math.exp(-rate * dt));
    return Math.abs(target - next) <= SNAP ? target : next;
}

// A dial's place between two slots ({ x, y, r })
function slotMix(a, b, t) {
    return { "x": mix(a.x, b.x, t), "y": mix(a.y, b.y, t), "r": mix(a.r, b.r, t) };
}
