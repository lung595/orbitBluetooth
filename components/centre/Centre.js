.pragma library

// Where things sit when a Listen together takes the centre of the scene
// (D281-D285): the source in the middle, its copies gravitating around it,
// and the host (the computer) small and dimmed at the back. Pure functions
// of the scene's geometry `g` (cx, cy, rx, ry, coreSize, bodySize); the QML
// only reads them. Tested by tests/centre.test.js.

var PERIOD = 25;        // seconds for one turn of the copies
var VOYAGE = 0.8;       // seconds the camera takes to follow the source to the centre
var FADE = 0.25;        // the same with Reduce motion: a short fade, no travel
var RECALL = 0.5;       // seconds the host takes to come back and the group to step back
var HOST_SIZE = 0.4;    // the host's size at the back, of its size at the centre
var GROUP_SIZE = 0.5;   // the group's size when it steps back
var TILT = 0.55;        // orbit height over width: the flat view of the scene's own rings
var MAX_SHIFT = 12;     // px the sky may drift: the margin around the starfield
var PARALLAX = 0.08;    // how far the sky follows the camera, far stars barely move

function clamp01(v) {
    return Math.max(0, Math.min(1, v));
}

function lerp(a, b, t) {
    return a + (b - a) * t;
}

// Smooth start and end for a 0..1 progress
function ease(t) {
    const x = clamp01(t);
    return x * x * (3 - 2 * x);
}

// Moves `value` toward `target` over `seconds` (linear, the easing is applied
// where the progress is used). Driven by the scene's own step, not by a QML
// animation, so a transition costs nothing once it has landed.
function approach(value, target, dt, seconds) {
    const step = dt / Math.max(0.001, seconds);
    return value < target ? Math.min(target, value + step) : Math.max(target, value - step);
}

// Where whatever steps back to sits: up on the left, behind the rings
function backSpot(g) {
    return { "x": g.cx - g.rx * 0.62, "y": g.cy - g.ry * 0.62 };
}

// Sizes in px: the source planet, a copy, and the distance from the source to a
// copy. The gap leaves room for the volume ring; on a small scene the copies
// shrink so the orbit still fits.
function sizes(g) {
    const source = Math.round(g.coreSize * 1.2);
    const gap = Math.max(14, g.bodySize * 0.4);
    const room = g.rx * 0.9;
    const copy = Math.max(12, Math.min(g.bodySize * 0.85, source * 0.5, 2 * (room - source / 2 - gap)));
    return { "source": source, "copy": copy, "radius": source / 2 + gap + copy / 2 };
}

// The group (source and copies): centred, or stepped back (stage 0..1, eased)
function groupAt(g, stage) {
    const b = backSpot(g);
    return { "x": lerp(g.cx, b.x, stage), "y": lerp(g.cy, b.y, stage), "scale": lerp(1, GROUP_SIZE, stage) };
}

// The host: at the centre, or at the back by `away` (0..1, eased)
function hostAt(g, away) {
    const b = backSpot(g);
    return { "x": lerp(g.cx, b.x, away), "y": lerp(g.cy, b.y, away), "scale": lerp(1, HOST_SIZE, away) };
}

// How far the host has moved to the back: the group takes the centre (0..1)
// unless it has stepped back to give the centre to the host (0..1)
function away(grouping, stage) {
    return ease(grouping) * (1 - ease(stage));
}

// The orbit's angle for a time on the orbit clock (it stops with the scene)
function phaseAt(orbitTime) {
    return orbitTime / PERIOD * Math.PI * 2 - Math.PI / 4;
}

// Copy i of n around the group's centre c, `radius` px away at full size.
// depth > 0 on the near side, as on the scene's rings.
function copySlot(radius, c, i, n, phase) {
    const a = phase + i / Math.max(1, n) * Math.PI * 2;
    return {
        "x": c.x + Math.cos(a) * radius * c.scale,
        "y": c.y + Math.sin(a) * radius * c.scale * TILT,
        "depth": Math.sin(a)
    };
}

// A copy is a little smaller on the far side, but never as small as a ring
// body: the orbit is tight
function depthSize(depth) {
    return 0.85 + 0.15 * depth;
}

// How far the sky drifts when the camera follows the source from `from` (its
// place on the ring) to the centre: a slight parallax, kept inside the margin
function parallax(g, from) {
    const cap = v => Math.max(-MAX_SHIFT, Math.min(MAX_SHIFT, v));
    return { "x": cap((g.cx - from.x) * PARALLAX), "y": cap((g.cy - from.y) * PARALLAX) };
}

// The members that are copies of the source, in the order they joined
function copiesOf(members, source) {
    return members.filter(a => a !== source);
}

// "source", "copy", or "" for a device outside the session
function roleOf(members, source, address) {
    if (members.indexOf(address) < 0)
        return "";
    return address === source ? "source" : "copy";
}

// The name under the centre: "XM6 + Marantz", the first two and "+N" for the
// rest when they would not fit
function label(names) {
    const all = names.filter(n => !!n);
    const full = all.join(" + ");
    if (all.length <= 2 || full.length <= 26)
        return full;
    return all.slice(0, 2).join(" + ") + " +" + (all.length - 2);
}

// A pulse travelling along the beam to copy i of n at `time`: how far along
// (0..1) and how bright. Pulses are spread so the beams do not beat together.
function pulse(time, i, n) {
    const at = (time * 0.5 + i / Math.max(1, n)) % 1;
    return { "at": at, "alpha": Math.sin(at * Math.PI) };
}
