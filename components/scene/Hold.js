.pragma library

// The long press, as numbers: how long a press must stay put to count as a right
// click, how far the pointer may wander meanwhile, and when its ring is drawn.
// Pure functions, tested by tests/hold.test.js.

// A press held this long (ms) acts as a right click (D368)
const HOLD_MS = 500;
// The pointer's drift (px) past which the press is a drag, not a hold: the same
// threshold the pointers use to pick a device up
const SLOP = 5;
// A click is over before this (ms): the ring is not drawn for it, so a plain click shows nothing
const RING_AFTER_MS = 120;

function clamp01(v) {
    return Math.max(0, Math.min(1, v));
}

// How much of the hold is done, 0..1, after `elapsed` ms
function progress(elapsed) {
    return clamp01(elapsed / HOLD_MS);
}

function done(elapsed) {
    return elapsed >= HOLD_MS;
}

function ringVisible(elapsed) {
    return elapsed >= RING_AFTER_MS;
}

// Has the pointer moved far enough from where it was pressed to be a drag?
function moved(from, to) {
    return Math.hypot(to.x - from.x, to.y - from.y) > SLOP;
}
