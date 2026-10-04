.pragma library
.import "Centre.js" as Centre
.import "Perspective.js" as Perspective

// The solar system of a Listen together: the group sits still in the middle
// of the view (the camera follows it) and the host, with the ring and the
// belt of the devices that are not in the group, revolves around it like a
// sun, always behind the group, smaller and further when it is on the far side
// of its path, bigger and nearer on the near side (the profile view's size,
// 1 / distance: Perspective.js). Pure functions of the scene's geometry `g`
// (cx, cy, rx, ry, ringCy, ringRy, innerNorm, snapNorm, detachNorm,
// outerMinNorm, bodySize, coreSize, holeX, holeY, holeHorizon); the QML only
// reads them. Tested by tests/sun.test.js.

var PERIOD = 60;                 // seconds for one turn of the sun, the pace of the ring's own drift
var SPAN = 0.45;                 // the sun's path: its half width, of the scene's rx
var SIZE = 0.45;                 // the system's size at the sun's mid distance, of its size at rest
var REST = -3 * Math.PI / 4;     // where the sun starts, and stays with Reduce motion: up on the left, behind
var STOP = 0.4;                  // seconds the sun takes to stop while a device is dragged, and to set off
var AT_REST = 50;                // stacking order of the host at rest, as before: under the bodies
var DROP = 1000;                 // stacking order the host's whole system loses under the group, so the group is always in front

// Where the system is for the sun at `phase` once the group has the centre by
// `away` (0..1): its centre, its scale, and its depth (> 0 on the near side,
// the bottom of the tilted path). At `away` 0 it is the scene as it always was.
function system(g, phase, away) {
    const reach = g.rx * SPAN;
    const depth = Math.sin(phase);
    return {
        "x": Perspective.lerp(g.cx, g.cx + Math.cos(phase) * reach, away),
        "y": Perspective.lerp(g.cy, g.cy + depth * reach * Centre.TILT, away),
        "k": Perspective.lerp(1, SIZE * Perspective.size(depth, 1) / Perspective.MID, away),
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
    const v = Perspective.copy(g);
    v.cx = t.x;
    v.cy = t.y;
    v.rx = g.rx * t.k;
    v.ry = g.ry * t.k;
    v.ringCy = t.y + (g.ringCy - g.cy) * t.k;
    v.ringRy = g.ringRy * t.k;
    v.bodySize = g.bodySize * t.k;
    v.coreSize = g.coreSize * t.k;
    return v;
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

// What the host's system loses of its stacking order: nothing while the host
// has the centre, all of DROP once the group has it (half way through the
// recall, where the two pass each other)
function drop(away) {
    return away > 0.5 ? DROP : 0;
}

// The host's stacking order among the bodies (their z is 100 + y). In the
// profile view the host sorts with them: a body on the far side of its ring is
// behind the host, one on the near side in front. Under the group's whole
// view it is far behind. At rest it keeps its usual place.
function hostZ(host, grouped, away) {
    return grouped ? 100 + host.y - drop(away) : AT_REST;
}
