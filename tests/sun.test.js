// The solar system of a Listen together: the sun's path around the group, its size with the
// distance, and the scene's own geometry as seen from it (slots, drag and separation unchanged).
// Run from the plugin root: gjs tests/sun.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const S = load("Sun.js", ["PERIOD", "SPAN", "SIZE", "REST", "STOP", "LIFT", "system", "advance", "view", "groupView", "lift", "hostZ", "groupZ"]);
const C = load("Centre.js", ["TILT", "sizes", "groupAt"]);
const P = load("Physics.js", ["norm", "ringSlot", "beltSlot", "dragArm", "separate"]);
const V = load("Perspective.js", ["MID", "size"]);

const near = v => Math.round(v * 1000) / 1000;

// A scene the way OrbitScene lays it out for a width and a height
function scene(width, height) {
    const bodySize = Math.round(Math.max(34, Math.min(width, height) * 0.135));
    const coreSize = Math.round(Math.min(width, height) * 0.17);
    const rx = Math.max(40, width / 2 - bodySize * 0.8), ry = Math.max(30, height / 2 - bodySize * 1.25);
    const cx = width / 2, cy = height / 2;
    const frontRy = ry * 0.56, backRy = Math.min(frontRy, coreSize * 0.5);
    return {
        width, height, cx, cy, rx, ry, bodySize, coreSize,
        innerNorm: 0.56, ringRy: (frontRy + backRy) / 2, ringCy: cy + (frontRy - backRy) / 2,
        outerMinNorm: 0.8, snapNorm: 0.7, detachNorm: 0.8, holeX: cx + rx, holeY: cy + ry, holeHorizon: Math.round(bodySize * 0.2)
    };
}
const g = scene(440, 380);
const phases = Array.from({ length: 72 }, (_, i) => S.REST + i / 72 * Math.PI * 2);

// --- the path -------------------------------------------------------------------
eq("sun: a turn takes 60 s (the pace of the ring's own drift, written out so a change is deliberate)", S.PERIOD, 60);
eq("sun: with the group not there, the system is the scene as it always was", (({ x, y, k }) => [x, y, k])(S.system(g, 1.3, 0)), [g.cx, g.cy, 1]);
const full = phase => S.system(g, phase, 1);
eq("sun: the path is a tilted ellipse around the group's centre", phases.map(p => near(Math.hypot((full(p).x - g.cx) / (g.rx * S.SPAN), (full(p).y - g.cy) / (g.rx * S.SPAN * C.TILT)))), Array(phases.length).fill(1));
eq("sun: it starts up on the left, on the far side", [full(S.REST).x < g.cx, full(S.REST).y < g.cy, full(S.REST).depth < 0], [true, true, true]);
eq("sun: at the bottom of the path it is nearest and biggest, at the top furthest and smallest", [near(full(Math.PI / 2).k), near(full(-Math.PI / 2).k), near(full(0).k)], [near(S.SIZE / V.MID), near(S.SIZE * V.size(-1, 1) / V.MID), near(S.SIZE)]);
eq("sun: its size is the profile view's, 1 / distance, all the way round", phases.map(p => near(full(p).k / S.SIZE * V.MID)), phases.map(p => near(V.size(Math.sin(p), 1))));
eq("sun: nearer is bigger and lower on the screen, all the way round", phases.every(p => (full(p).k > S.SIZE) === (full(p).y > g.cy + 1e-9) || Math.abs(full(p).k - S.SIZE) < 1e-9), true);
eq("sun: half way to the centre when the group is half there", [near(S.system(g, 0, 0.5).x - g.cx), near(S.system(g, 0, 0.5).k)], [near(g.rx * S.SPAN / 2), near((1 + S.SIZE) / 2)]);

// --- it fits the view ----------------------------------------------------------
for (const [width, height] of [[440, 380], [340, 320], [320, 460], [600, 500], [800, 600], [300, 240]]) {
    const v = scene(width, height);
    const out = phases.map(p => {
        const t = S.system(v, p, 1);
        const reach = (v.rx + v.bodySize / 2) * t.k;
        return Math.max(t.x + reach - width, -(t.x - reach), t.y + (v.ry + v.bodySize / 2) * t.k - height, -(t.y - (v.ry + v.bodySize / 2) * t.k));
    });
    eq("fit " + width + "x" + height + ": the whole system stays inside the view all the way round", Math.max(...out) <= 0, true);
}

// --- time ----------------------------------------------------------------------
eq("advance: a full turn takes PERIOD seconds, half speed takes twice", [near(S.advance(0, S.PERIOD, 1)), near(S.advance(0, S.PERIOD, 0.5))], [near(2 * Math.PI), near(Math.PI)]);
eq("advance: stopped, the sun stays where it is", S.advance(1.234, 0.5, 0), 1.234);

// --- the scene as seen from the system -----------------------------------------
const home = { x: g.cx, y: g.cy, k: 1 };
const same = S.view(g, home);
eq("view: from the middle at full size it is the scene itself", [same.cx, same.cy, same.rx, same.ry, same.ringCy, same.ringRy, same.bodySize, same.coreSize], [g.cx, g.cy, g.rx, g.ry, g.ringCy, g.ringRy, g.bodySize, g.coreSize]);
const t = S.system(g, 0.6, 1);
const v = S.view(g, t);
eq("view: centred on the sun and scaled by its size", [v.cx, v.cy, near(v.rx), near(v.ry), near(v.bodySize), near(v.coreSize)], [t.x, t.y, near(g.rx * t.k), near(g.ry * t.k), near(g.bodySize * t.k), near(g.coreSize * t.k)]);
eq("view: the shares of the belt (ring, magnet, tear) are the same", [v.innerNorm, v.snapNorm, v.detachNorm, v.outerMinNorm], [g.innerNorm, g.snapNorm, g.detachNorm, g.outerMinNorm]);
eq("view: the black hole stays where and as big as it is", [v.holeX, v.holeY, v.holeHorizon], [g.holeX, g.holeY, g.holeHorizon]);
const ring = [0, 1, 2].map(i => [P.ringSlot(g, i, 3, 0.4), P.ringSlot(v, i, 3, 0.4)]);
eq("view: a slot of the connected ring is the usual slot, moved and scaled with the system", ring.map(([a, b]) => [near(b.x), near(b.y), near(b.depth)]), ring.map(([a, b]) => [near(t.x + (a.x - g.cx) * t.k), near(t.y + (a.y - g.cy) * t.k), near(a.depth)]));
const belt = P.beltSlot(g, 2, 5, 0.1, 0.4, 0.9, 0, 0), beltV = P.beltSlot(v, 2, 5, 0.1, 0.4, 0.9, 0, 0);
eq("view: the same for a slot of the outer belt", [near(beltV.x), near(beltV.y)], [near(t.x + (belt.x - g.cx) * t.k), near(t.y + (belt.y - g.cy) * t.k)]);
eq("view: the distance to the sun is measured in the system's own units", [near(P.norm(v, t.x, t.y)), near(P.norm(v, t.x + g.rx * t.k * 0.5, t.y))], [0, 0.5]);
eq("view: a body keeps the room it needs, scaled (separation sees the smaller discs)", (() => {
    const big = { px: 0, py: 0, inSlot: true }, other = { px: g.bodySize * t.k * 0.7, py: 0, leaving: false, dragging: false };
    const a = { x: 0, y: 0 }, b = { x: 0, y: 0 };
    P.separate(g, big, a, [other], true);
    P.separate(v, big, b, [other], true);
    return Math.abs(b.x) < Math.abs(a.x);
})(), true);
eq("view: a copy that is a plain object, safe to adjust", [S.view(g, home) !== g, S.view(g, home) !== S.view(g, home)], [true, true]);

// --- the group's own geometry, for the members dragged out of it -----------------
const sz = C.sizes(g);
// The group's slot on the host's ring: far side, a little to the right
const slot = P.ringSlot(g, 1, 4, 0.4);
const grp = S.groupView(g, sz, C.groupAt(g, 0, slot));
const where = (dx, dy) => P.dragArm(grp, true, g.cx + dx, g.cy + dy).armed;
eq("group: centred on the view, the ring is the copies' orbit", [grp.cx, grp.cy, grp.ringCy, near(grp.rx * grp.innerNorm), near(grp.ringRy)], [g.cx, g.cy, g.cy, near(sz.radius), near(sz.radius * C.TILT)]);
eq("group: a member is still held inside the orbit and at its edge, let go one body beyond", [where(0, 0), where(sz.radius + sz.copy / 2, 0), where(sz.radius + sz.copy / 2 + g.bodySize * 1.1, 0)], [false, false, true]);
const back = C.groupAt(g, 1, slot);
const gb = S.groupView(g, sz, back);
eq("group: stepped back it is smaller and elsewhere, and so is where a member is let go", [gb.cx === back.x, gb.cy === back.y, near(gb.rx), near(gb.rx * gb.innerNorm), near(gb.rx * gb.detachNorm)], [true, true, near(g.rx * back.scale), near(sz.radius * back.scale), near((sz.radius + sz.copy / 2 + g.bodySize) * back.scale)]);

// --- the host's stacking order ---------------------------------------------------
eq("z: at rest the host keeps its usual place", S.hostZ({ y: g.cy }, false), 50);
eq("z: in the profile view the host sorts with the bodies (100 + y): its ring's far side is behind it, the near side in front", [S.hostZ({ y: g.cy }, true), 100 + (g.cy - 20) < S.hostZ({ y: g.cy }, true), 100 + (g.cy + 20) > S.hostZ({ y: g.cy }, true)], [100 + g.cy, true, true]);
eq("z: half way through the recall the host is still in front, then the group is lifted over it", [S.lift(0), S.lift(0.5), S.lift(0.51), S.lift(1)], [0, 0, S.LIFT, S.LIFT]);
// Fedora's view: the group is a planet on the host's ring and sorts by its height like any body
eq("z: on the near side of the host's ring the group is in front of the host, on the far side behind it", [S.groupZ({ y: g.cy + 20 }, 0) > S.hostZ({ y: g.cy }, true), S.groupZ({ y: g.cy - 20 }, 0) < S.hostZ({ y: g.cy }, true)], [true, true]);
// The group's own view: its lowest member is a far copy, depth -1, one below its z
const lowest = S.groupZ({ y: g.cy }, 1) - 1;
eq("z: in the group's view the whole system is behind the group, all the way round the sun's path", phases.every(p => S.hostZ(full(p), true) < lowest), true);
eq("z: so is the nearest body of that system and any body in the scene (z = 100 + y)", [100 + g.cy + g.ry < lowest, 100 + g.height < lowest], [true, true]);

done();
