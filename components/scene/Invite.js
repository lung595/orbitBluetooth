.pragma library

// The invitation to listen together, as pure functions of the effects clock
// and of where two bodies are: how a halo breathes, how strongly the thread
// of light shows as the carried device nears one it could join, and where the
// light dots on that thread are. Bodies are { px, py } and a radius in scene
// pixels. Tested by tests/invite.test.js.

// Light dots on the thread, and a full run of one dot, in seconds
var DOTS = 6;
var RUN = 1.25;

// Breath of a halo, 0..1 (each target a little apart from the others)
function breath(t, index) {
    return 0.5 + 0.5 * Math.sin(t * 3.2 + index * 1.7);
}

// How much the thread shows, 0.35 (afar, so the invitation is seen from the
// start of the drag) to 1 (the edges touch), from the gap between the edges
function strength(gap, bodySize) {
    return 0.35 + 0.65 * Math.min(1, Math.max(0, 1 - gap / (bodySize * 3.5)));
}

// Where dot `i` is along the gap, 0..1: runs from the carried device to the
// target on the clock, or stays at its place with Reduce motion
function dotAt(t, i, motion) {
    return motion ? (t / RUN + i / DOTS) % 1 : (i + 0.5) / DOTS;
}

// A dot is dim at both ends of its run, so it is born and dies unseen
function dotAlpha(u) {
    return Math.sin(Math.PI * u);
}

// The thread from `a`'s edge to `b`'s edge: its start, angle (degrees) and
// length, which is the gap between the edges (0 when they overlap)
function thread(a, aR, b, bR) {
    const dx = b.px - a.px, dy = b.py - a.py;
    const d = Math.hypot(dx, dy) || 1;
    return {
        "x": a.px + dx / d * aR,
        "y": a.py + dy / d * aR,
        "angle": Math.atan2(dy, dx) * 180 / Math.PI,
        "length": Math.max(0, d - aR - bR)
    };
}

// The index of the target nearest to body `a`, or -1 when there is none
function nearest(a, targets) {
    let best = -1, bestD = Infinity;
    for (let i = 0; i < targets.length; i++) {
        const d = Math.hypot(targets[i].px - a.px, targets[i].py - a.py);
        if (d < bestD) {
            best = i;
            bestD = d;
        }
    }
    return best;
}
