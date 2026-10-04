.pragma library
.import "Centre.js" as Centre

// The solar system of a Listen together: the group sits still in the middle
// of the view (the camera follows it) and the host, with the ring and the
// belt of the devices that are not in the group, revolves around it like a
// sun, smaller and further when it is behind, bigger and nearer in front.
// Pure functions of the scene's geometry `g` (cx, cy, rx, ry, ringCy, ringRy,
// innerNorm, snapNorm, detachNorm, outerMinNorm, bodySize, coreSize, holeX,
// holeY, holeHorizon); the QML only reads them. Tested by tests/sun.test.js.

var PERIOD = 60;                 // seconds for one turn of the sun, the pace of the ring's own drift
var SPAN = 0.45;                 // the sun's path: its half width, of the scene's rx
var SIZE = 0.6;                  // the system's size at the sun's mid distance, of its size at rest
var DEPTH = 0.12;                // how much bigger when nearest, smaller when furthest (of SIZE)
var REST = -3 * Math.PI / 4;     // where the sun starts, and stays with Reduce motion: up on the left, behind
var STOP = 0.4;                  // seconds the sun takes to stop while a device is dragged, and to set off
var BEHIND = 8;                  // stacking order of the host behind the group (under the ring's far side)
var AT_REST = 50;                // ...and at rest, as before: above the far side of the ring, under the bodies

// Where the system is for the sun at `phase` once the group has the centre by
// `away` (0..1): its centre, its scale, and its depth (> 0 on the near side,
// the bottom of the tilted path). At `away` 0 it is the scene as it always was.
function system(g, phase, away) {
    const reach = g.rx * SPAN;
    const depth = Math.sin(phase);
    return {
        "x": Centre.lerp(g.cx, g.cx + Math.cos(phase) * reach, away),
        "y": Centre.lerp(g.cy, g.cy + depth * reach * Centre.TILT, away),
        "k": Centre.lerp(1, SIZE * (1 + DEPTH * depth), away),
        "depth": depth
    };
}

// The sun's angle `dt` seconds on, at `speed` (0 stopped .. 1 full)
function advance(phase, dt, speed) {
    return phase + dt * speed / PERIOD * Math.PI * 2;
}

// The scene's geometry as seen from the system `t` ({ x, y, k }): the same
// rings and belt, centred on the sun and scaled, so the scene's motion maths
// (slots, drag, separation) work on it unchanged. A new plain object each
// time, safe to adjust; the black hole stays where and as big as it is.
function view(g, t) {
    return {
        "cx": t.x,
        "cy": t.y,
        "rx": g.rx * t.k,
        "ry": g.ry * t.k,
        "ringCy": t.y + (g.ringCy - g.cy) * t.k,
        "ringRy": g.ringRy * t.k,
        "innerNorm": g.innerNorm,
        "snapNorm": g.snapNorm,
        "detachNorm": g.detachNorm,
        "outerMinNorm": g.outerMinNorm,
        "bodySize": g.bodySize * t.k,
        "coreSize": g.coreSize * t.k,
        "holeX": g.holeX,
        "holeY": g.holeY,
        "holeHorizon": g.holeHorizon
    };
}

// The geometry a member of the group is dragged in: the group is the ring it
// is pulled back to, and it leaves one body past the copies' orbit. `s` is
// Centre.sizes(g), `c` Centre.groupAt() (where the group is, and its scale).
function groupView(g, s, c) {
    const v = view(g, { "x": c.x, "y": c.y, "k": c.scale });
    v.ringCy = c.y;
    v.ringRy = s.radius * c.scale * Centre.TILT;
    v.innerNorm = s.radius / g.rx;
    v.detachNorm = (s.radius + s.copy / 2 + g.bodySize) / g.rx;
    return v;
}

// The host's stacking order among the bodies (their z is 100 + y): in front
// of the group's source once the sun is on the near side, behind the whole
// group on the far side. At rest it keeps its usual place.
function hostZ(g, host, grouped) {
    if (!grouped)
        return AT_REST;
    return host.y > g.cy ? 100 + host.y : BEHIND;
}
