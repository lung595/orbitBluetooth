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
var COPY_LIFT = 0.5;                // a copy's order over the source's at the middle of its orbit: under 1, so that nothing outside the group sorts between them
var ORBIT_SPREAD = 1.4;             // how much farther than a tight ring the copies orbit while the group has the centre (spreadAt): the source and its gauge stay in the clear, and a copy passing behind the source covers little of it
var BEHIND_SPAN = 0.25;             // depth either side of the horizon (0) over which a copy turns from whole to its dashed outline
var BEHIND_INK = 0.7;               // how much of its glyph a copy keeps while it is only an outline
var GLYPH_DISC = 0.34;              // a member's disc in the row of icons under the group, of the host's core size
var GLYPH_OVERLAP = 0.18;           // how much of a disc the next one covers: the bar pill's 4 px on its 22 px discs
var GLYPH_MIN = 14;                 // px: the smallest disc, so a glyph can still be read when the group steps back

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

// How much farther than a tight ring the copies orbit, for a stage (0..1: how
// far the group has stepped back onto the host's ring): ORBIT_SPREAD while it
// has the centre, a tight ring once it is one more planet on the host's ring,
// where a wide orbit would cross the host and its neighbours. It follows the
// group's own easing (groupAt), so the orbit and the group arrive together.
function spreadAt(stage) {
    return Perspective.lerp(ORBIT_SPREAD, 1, ease(stage));
}

// Sizes in px: the source planet, the volume ring around it, a copy, and the
// distance from the source to a copy. The source is as big as the host's core
// (the same planet, now at the centre); the ring sits just outside what it
// already wears (battery arc, noise-control halo) and the copies orbit
// outside the ring, `spread` times as far as a tight ring would put them
// (spreadAt); on a small scene the copies shrink so that orbit still fits.
function sizes(g, spread = ORBIT_SPREAD) {
    const source = g.coreSize;
    const ring = source / 2 + Math.max(16, source * 0.2);
    const gap = ring - source / 2 + 12;
    const room = g.rx * 0.9;
    const copy = Math.max(12, Math.min(g.bodySize * 0.85, source * 0.5, 2 * (room / spread - source / 2 - gap)));
    // The speaker that crowns the volume ring and the chip behind it: CentreRing
    // draws them at this size
    const chipIcon = Math.max(10, Math.round(source * 0.22));
    return { "source": source, "ring": ring, "copy": copy, "radius": (source / 2 + gap + copy / 2) * spread, "chipIcon": chipIcon, "chip": chipIcon + 8 };
}

// How far from the group's centre (px, at full size) the icons of its members
// start: past the ring and past the extreme point of the copies' orbit, so a
// copy passing in front never covers them. Over the group (`above`) the speaker
// that crowns the ring sticks out of it, and the icons clear it too.
function glyphsOffset(s, above) {
    const ring = s.ring + (above ? s.chip / 2 : 0);
    return Math.max(ring, s.radius * TILT + s.copy / 2) + 6;
}

// A member's disc (px) in that row: a share of the host's core, as big as the
// group is (`scale`: 1 in the middle, smaller on the host's ring), but never so
// small that its glyph cannot be read
function glyphDisc(coreSize, scale) {
    return Math.max(GLYPH_MIN, Math.round(coreSize * GLYPH_DISC * scale));
}

// The gap between two discs (px, negative: they overlap), as the bar pill's
function glyphSpacing(disc) {
    return -Math.round(disc * GLYPH_OVERLAP);
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

// The stacking order (z) of device body `b` among its siblings. In the scene's
// own view the far half of the connected ring passes behind the host's core
// (z 50) and the rest sorts by height. In the profile view everything sorts by
// height, the host among them. The members of the group keep together around
// the group's own order `groupZ` (Sun.groupZ): the source in the middle of it,
// its copies always over it, the near ones in front of the far ones. A copy
// behind the source is not hidden by it: it is drawn as a dashed outline
// (solidity) and answers a click first, instead of waiting for its turn round
// to the front.
function bodyZ(b, grouped, groupZ) {
    if (b.role)
        return groupZ + (b.role === "source" ? 0 : COPY_LIFT + b.depth * COPY_LIFT / 2);
    if (!grouped && b.inSlot && b.depth < 0)
        return 10 + b.py * 0.01;
    return 100 + b.py;
}

// How whole a member of the group is drawn (0..1): a copy that passes behind
// the source is drawn over it, so it gives up its disc and keeps only a dashed
// outline (0, whatever the view), and is whole again on the near side (1); it
// turns over BEHIND_SPAN of depth either side of the horizon, where it is
// clear of the source. The source, and what is not in the group, are always
// whole. `mix` (0..1) is how far the member has taken its place in the group,
// so that nothing pops when a device joins.
function solidity(role, depth, mix) {
    if (role !== "copy")
        return 1;
    return Perspective.lerp(1, ease((depth + BEHIND_SPAN) / (2 * BEHIND_SPAN)), clamp01(mix));
}

// How much of its glyph a member keeps (0..1) at a solidity: the glyph stays
// readable once the disc behind it has gone
function inkOf(solid) {
    return Perspective.lerp(BEHIND_INK, 1, clamp01(solid));
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

// Where a member of the group sits and how big it is (px): the source in the
// middle at the size of the host's core, copy `i` of `n` on the orbit. One rule
// for every kind of member, so a wired output sits exactly where a Bluetooth
// one would (D298). `sz` is sizes(g), `c` the group's { x, y, scale }.
function place(sz, c, role, i, n, phase) {
    if (role === "source")
        return { "x": c.x, "y": c.y, "depth": 1, "size": sz.source * c.scale };
    const slot = copySlot(sz.radius, c, i, n, phase);
    return { "x": slot.x, "y": slot.y, "depth": slot.depth, "size": sz.copy * c.scale * depthSize(slot.depth) };
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

// A pulse travelling along the beam to copy i of n at `time`: how far along
// (0..1) and how bright. Pulses are spread so the beams do not beat together.
function pulse(time, i, n) {
    const at = (time * 0.5 + i / Math.max(1, n)) % 1;
    return { "at": at, "alpha": Math.sin(at * Math.PI) };
}
