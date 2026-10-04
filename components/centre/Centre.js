.pragma library
.import "Perspective.js" as Perspective

// Where things sit when a Listen together takes the centre of the scene
// (D281-D285): the source in the middle, its copies gravitating around it,
// and the host (the computer) revolving around the group as a sun (Sun.js).
// Everything is seen in profile (Perspective.js, D294). Pure functions of the
// scene's geometry `g` (cx, cy, rx, ry, coreSize, bodySize); the QML only
// reads them. Tested by tests/centre.test.js.

var PERIOD = 25;                    // seconds for one turn of the copies
var VOYAGE = 0.8;                   // seconds the camera takes to follow the source to the centre
var FADE = 0.25;                    // the same with Reduce motion: a short fade, no travel
var RECALL = 0.5;                   // seconds the host takes to come back and the group to step back
var GROUP_SIZE = 0.7;               // the group's size on its ring slot at the nearest point, of its size in the middle
var TILT = Perspective.FLAT;        // orbit height over width: the profile view's, one value for every orbit
var MAX_SHIFT = 12;                 // px the sky may drift: the margin around the starfield
var PARALLAX = 0.08;                // how far the sky follows the camera, far stars barely move

function clamp01(v) {
    return Math.max(0, Math.min(1, v));
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

// A size in px that follows its goal at the pace of the voyage: `ref` is the
// biggest size it can take (the step is a share of it, so a big change takes
// as long as `seconds` and a small one less). Not set yet (0): at the goal at
// once, so a planet that joins grows from its ring size, not from nothing.
function grow(value, goal, ref, dt, seconds) {
    if (value <= 0)
        return goal;
    return ref * approach(value / ref, goal / ref, dt, seconds);
}

// Sizes in px: the source planet, the volume ring around it, a copy, and the
// distance from the source to a copy. The source is as big as the host's core
// (the same planet, now at the centre); the ring sits just outside what it
// already wears (battery arc, noise-control halo) and the copies orbit
// outside the ring; on a small scene the copies shrink so the orbit still fits.
function sizes(g) {
    const source = g.coreSize;
    const ring = source / 2 + Math.max(16, source * 0.2);
    const gap = ring - source / 2 + 12;
    const room = g.rx * 0.9;
    const copy = Math.max(12, Math.min(g.bodySize * 0.85, source * 0.5, 2 * (room - source / 2 - gap)));
    return { "source": source, "ring": ring, "copy": copy, "radius": source / 2 + gap + copy / 2 };
}

// How far under the group's centre (px, at full size) the name goes: below
// the ring and below the lowest point of the copies' orbit, so a copy passing
// in front never covers it
function labelOffset(s) {
    return Math.max(s.ring, s.radius * TILT + s.copy / 2) + 8;
}

// The group (source and copies): centred and in front, or stepped back (stage
// 0..1, eased) onto its slot on the host's ring like one more planet, as big
// as a body is at that depth: it passes in front of the host, then behind it.
// `slot` is { x, y, depth } as Physics.ringSlot gives it.
function groupAt(g, stage, slot) {
    return {
        "x": Perspective.lerp(g.cx, slot.x, stage),
        "y": Perspective.lerp(g.cy, slot.y, stage),
        "scale": Perspective.lerp(1, GROUP_SIZE * Perspective.size(slot.depth, 1), stage),
        "depth": Perspective.lerp(1, slot.depth, stage)
    };
}

// How far the host has left the centre for its path around the group (0..1):
// the group takes the centre (0..1) unless it has stepped back to give the
// centre to the host (0..1)
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
