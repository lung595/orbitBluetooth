.pragma library

// The profile view (D294): while a Listen together has the scene, the system
// is seen from almost level with its orbits. Every orbit is then a flat
// ellipse, and a body is as big as it is near the camera: its size follows
// 1 / distance, and the further it is the darker it gets. Pure functions of a
// scene geometry `g` (cx, cy, rx, ry, ringCy, ringRy, innerNorm, snapNorm,
// detachNorm, outerMinNorm, bodySize, coreSize, holeX, holeY, holeHorizon) and
// of how far the scene has gone into that view (`profile`, 0..1; 0 is the
// scene as it always was). The QML only reads them. Tested by
// tests/perspective.test.js.

var PITCH = 15 * Math.PI / 180;   // the camera's angle above the plane of the orbits
var FLAT = Math.tan(PITCH);       // height over width of an orbit seen at that angle
var REACH = 1 / 3;                // an orbit's radius, in units of the camera's distance to its nearest point
var MID = 0.75;                   // size on an orbit's middle line, the same in both views

// The fields of a geometry; a scene is a QML item, so a copy names them
var FIELDS = ["cx", "cy", "rx", "ry", "ringCy", "ringRy", "innerNorm", "snapNorm", "detachNorm", "outerMinNorm", "bodySize", "coreSize", "holeX", "holeY", "holeHorizon"];

function lerp(a, b, t) {
    return a + (b - a) * t;
}

// A plain object with the fields of geometry `g`, safe to adjust
function copy(g) {
    const o = {};
    for (const key of FIELDS)
        o[key] = g[key];
    return o;
}

// How far the camera is from a body at `depth` on an orbit (1 on its nearest
// point .. -1 on its furthest), the nearest point being at distance 1
function distance(depth) {
    return 1 + (1 - depth) * REACH;
}

// A body's size at `depth`, of its size on the nearest point. The scene's own
// law is linear in the depth; the profile view's is 1 / distance. Both give
// MID on the middle line and 1 on the nearest point.
function size(depth, profile) {
    return lerp(MID + (1 - MID) * depth, 1 / distance(depth), profile);
}

// How much of its colour a body keeps at `depth` (0..1): the scene's own soft
// fade, then in the profile view as much as it keeps of its size, so what is
// far is small and dark together
function haze(depth, profile) {
    return lerp(0.8 + 0.2 * size(depth, 0), size(depth, 1), profile);
}

// How much bigger or smaller than usual a body of the outer belt looks at
// `depth`: it has no ring slot to give it a size, so this is a factor on its own
// (1 on the middle line, and everywhere in the scene's own view)
function lean(depth, profile) {
    return lerp(1, size(depth, 1) / MID, profile);
}

// The depth of a body that has no orbit slot, from where it is: the lower on
// the screen the nearer. `g` is the geometry the body lives in.
function depthAt(g, y) {
    return Math.max(-1, Math.min(1, (y - g.cy) / Math.max(1, g.ry)));
}

// The same factor for a body that floats at screen height `y` (the black hole):
// its depth from where it is, then how much bigger or smaller it looks. `g` is
// the geometry it lives in (the flat one, see `flat`).
function leanAt(g, y, profile) {
    return lean(depthAt(g, y), profile);
}

// The scene's geometry as the profile view sees it: the orbits flattened to
// FLAT and the connected ring centred on the host (from level, the ring's near
// and far edges are the same distance from its middle). `g` itself, not a
// copy, while the scene is not in that view; never taller than it was.
function flat(g, profile) {
    if (profile <= 0)
        return g;
    const o = copy(g);
    o.ry = lerp(g.ry, Math.min(g.ry, g.rx * FLAT), profile);
    o.ringRy = lerp(g.ringRy, Math.min(g.ringRy, g.rx * g.innerNorm * FLAT), profile);
    o.ringCy = lerp(g.ringCy, g.cy, profile);
    return o;
}
