// The profile view of a Listen together: flat orbits seen ~15 degrees above their plane, a size that
// follows 1 / distance, and the haze that darkens what is far (D294).
// Run from the plugin root: gjs tests/perspective.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const P = load("Perspective.js", ["PITCH", "FLAT", "REACH", "MID", "FIELDS", "lerp", "copy", "distance", "size", "haze", "depthAt", "flat"]);

const near = v => Math.round(v * 1000) / 1000;

// A scene the way OrbitScene lays it out for a bar popout
const g = {
    cx: 220, cy: 190, rx: 179, ry: 126, ringCy: 190 + (70.56 - 32) / 2, ringRy: (70.56 + 32) / 2, innerNorm: 0.56, snapNorm: 0.7, detachNorm: 0.8,
    outerMinNorm: 0.8, bodySize: 51, coreSize: 65, holeX: 399, holeY: 316, holeHorizon: 10
};

// --- the camera ----------------------------------------------------------------
eq("camera: 15 degrees above the plane of the orbits, written out so a change is deliberate", near(P.PITCH * 180 / Math.PI), 15);
eq("camera: so an orbit is 0.268 as tall as it is wide", near(P.FLAT), 0.268);
eq("lerp: the ends and the middle", [P.lerp(2, 6, 0), P.lerp(2, 6, 1), P.lerp(2, 6, 0.5)], [2, 6, 4]);

// --- size = 1 / distance --------------------------------------------------------
eq("distance: 1 on the nearest point of an orbit, a third more on its far edge's middle line", [near(P.distance(1)), near(P.distance(0)), near(P.distance(-1))], [1, 1.333, 1.667]);
eq("size: in the profile view it is exactly 1 / distance, all the way round", [-1, -0.5, 0, 0.5, 1].map(d => near(P.size(d, 1) * P.distance(d))), Array(5).fill(1));
eq("size: nearest is 1 and the middle line MID in both views, whatever the mix", [0, 0.4, 1].map(p => [near(P.size(1, p)), near(P.size(0, p))]), Array(3).fill([1, P.MID]));
eq("size: the scene's own law is linear, the profile view's keeps the far side bigger", [near(P.size(-1, 0)), near(P.size(-1, 1))], [0.5, 0.6]);
eq("size: nearer is always bigger, in both views", [0, 1].map(p => [-1, -0.5, 0, 0.5, 1].map(d => P.size(d, p)).every((v, i, all) => i === 0 || v > all[i - 1])), [true, true]);
eq("size: half way in is half way between the two laws", near(P.size(-1, 0.5)), near((0.5 + 0.6) / 2));

// --- haze -----------------------------------------------------------------------
eq("haze: the scene's own soft fade, 0.8 + 0.2 of its size, without the profile view", [-1, 0, 1].map(d => near(P.haze(d, 0))), [0.9, 0.95, 1]);
eq("haze: in the profile view a body keeps as much colour as it has size", [-1, 0, 1].map(d => near(P.haze(d, 1))), [0.6, 0.75, 1]);
eq("haze: the further the darker, in both views", [0, 1].map(p => [-1, -0.5, 0, 0.5, 1].map(d => P.haze(d, p)).every((v, i, all) => i === 0 || v > all[i - 1])), [true, true]);
eq("haze: a nearest body is never dimmed", [P.haze(1, 0), P.haze(1, 0.5), P.haze(1, 1)], [1, 1, 1]);

// --- a body that has no slot -----------------------------------------------------
eq("depthAt: on the middle line it is 0, at the bottom of the belt 1, at the top -1", [P.depthAt(g, g.cy), P.depthAt(g, g.cy + g.ry), P.depthAt(g, g.cy - g.ry)], [0, 1, -1]);
eq("depthAt: lower on the screen is nearer, and it stays in -1..1 off the belt", [P.depthAt(g, g.cy + g.ry / 2), P.depthAt(g, g.cy + g.ry * 5), P.depthAt(g, g.cy - g.ry * 5)], [0.5, 1, -1]);
eq("depthAt: a flat belt reads the same way", P.depthAt({ cy: 100, ry: 0 }, 100.5), 0.5);

// --- the geometry of the view -----------------------------------------------------
eq("flat: not in the profile view, it is the scene itself", P.flat(g, 0) === g, true);
const f = P.flat(g, 1);
eq("flat: a plain copy that names every field", [f !== g, P.FIELDS.every(k => k in f)], [true, true]);
eq("flat: the belt is 0.268 as tall as it is wide", near(f.ry / f.rx), near(P.FLAT));
eq("flat: so is the connected ring, and it is centred on the host", [near(f.ringRy / (f.rx * f.innerNorm)), f.ringCy], [near(P.FLAT), g.cy]);
eq("flat: nothing else moves or changes size", P.FIELDS.filter(k => !["ry", "ringRy", "ringCy"].includes(k)).map(k => f[k]), P.FIELDS.filter(k => !["ry", "ringRy", "ringCy"].includes(k)).map(k => g[k]));
eq("flat: the scene it is made from is left as it was", [g.ry, g.ringRy], [126, 51.28]);
const half = P.flat(g, 0.5);
eq("flat: half way in is half way between", [near(half.ry), near(half.ringRy), near(half.ringCy)], [near((g.ry + f.ry) / 2), near((g.ringRy + f.ringRy) / 2), near((g.ringCy + g.cy) / 2)]);
eq("flat: a scene that is already low is never made taller", [P.flat({ cx: 0, cy: 0, rx: 200, ry: 20, ringCy: 3, ringRy: 8, innerNorm: 0.56 }, 1).ry, P.flat({ cx: 0, cy: 0, rx: 200, ry: 20, ringCy: 3, ringRy: 8, innerNorm: 0.56 }, 1).ringRy], [20, 8]);

done();
