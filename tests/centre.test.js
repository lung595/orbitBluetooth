// Listen together at the centre of the scene: the copies' orbit, the host and the group stepping
// back, the sky's parallax, the label, and the general volume that keeps the gaps (D281-D285).
// Run from the plugin root: gjs tests/centre.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const C = load("Centre.js", ["PERIOD", "MAX_SHIFT", "GROUP_SIZE", "TILT", "clamp01", "ease", "approach", "grow", "sizes", "labelOffset", "groupAt", "bodyZ", "seeThrough", "COPY_LIFT", "SEE_THROUGH", "away", "phaseAt", "copySlot", "depthSize", "parallax", "copiesOf", "roleOf", "label", "pulse"]);
const V = load("MasterVolume.js");
const P = load("Perspective.js", ["FLAT", "size"]);

const near = (v, d) => Math.round(v * 1000) / 1000;
const round = list => list.map(near);

// A scene the size of the bar popout, and a small one
const g = { cx: 210, cy: 190, rx: 170, ry: 125, coreSize: 65, bodySize: 51 };
const small = { cx: 110, cy: 100, rx: 83, ry: 57, coreSize: 34, bodySize: 34 };

// --- progress -------------------------------------------------------------------
eq("ease: starts and ends flat, half way is half", [C.ease(0), C.ease(0.5), C.ease(1)], [0, 0.5, 1]);
eq("ease: stays in 0..1", [C.ease(-3), C.ease(7)], [0, 1]);
eq("approach: a step of dt over the duration, never past the target", [near(C.approach(0, 1, 0.2, 0.8)), C.approach(0.9, 1, 0.2, 0.8), C.approach(1, 0, 0.4, 0.8)], [0.25, 1, 0.5]);
eq("approach: a zero duration lands at once", C.approach(0, 1, 0.03, 0), 1);
// A size in px follows its goal at the pace of the voyage (a new source does not pop)
const walk = (from, goal, ref, steps) => { const path = [from]; for (let i = 0; i < steps; i++) path.push(C.grow(path[i], goal, ref, 0.1, 0.8)); return path; };
eq("grow: a big change takes the whole voyage, a step at a time", walk(65, 32, 65, 8).map(near), [65, 56.875, 48.75, 40.625, 32.5, 32, 32, 32, 32].map(near));
eq("grow: it never goes past the goal, up or down", [walk(65, 32, 65, 12), walk(32, 65, 65, 12)].map(path => path.every(v => v >= 32 && v <= 65)), [true, true]);
eq("grow: one way only, no pop and no wobble on the way", [walk(65, 32, 65, 12), walk(32, 65, 65, 12)].map(path => path.every((v, i) => i === 0 || (path[0] > path[path.length - 1] ? v <= path[i - 1] : v >= path[i - 1]))), [true, true]);
eq("grow: a goal that is already there stays", C.grow(32, 32, 65, 0.03, 0.8), 32);
eq("grow: a planet that has no size yet appears at its goal", C.grow(0, 32, 65, 0.03, 0.8), 32);
eq("away: the host is at the back once the group has the centre", [C.away(0, 0), C.away(1, 0), C.away(1, 1), C.away(0.5, 0)], [0, 1, 0, 0.5]);

// --- where things sit -----------------------------------------------------------
// The group's slot on the host's ring: the far side, a little to the left
const slot = { x: g.cx - 60, y: g.cy - 20, depth: -0.8 };
eq("tilt: one value for every orbit, the profile view's (15 degrees)", C.TILT, P.FLAT);
eq("group: at the centre and in front, then stepped back onto its slot, smaller", [C.groupAt(g, 0, slot), C.groupAt(g, 1, slot)], [{ x: g.cx, y: g.cy, scale: 1, depth: 1 }, { x: slot.x, y: slot.y, scale: C.GROUP_SIZE * P.size(slot.depth, 1), depth: slot.depth }]);
eq("group: half way is half way, on the line between the two", [C.groupAt(g, 0.5, slot).x, C.groupAt(g, 0.5, slot).y, near(C.groupAt(g, 0.5, slot).depth)], [g.cx - 30, g.cy - 10, near((1 - 0.8) / 2)]);
eq("group: on the ring it is as big as a body is at that depth, nearest biggest", [1, 0.5, 0, -0.5, -1].map(depth => C.groupAt(g, 1, { x: 0, y: 0, depth }).scale).every((v, i, all) => i === 0 || v < all[i - 1]), true);
eq("group: nearest on the ring it is GROUP_SIZE of its size in the middle", C.groupAt(g, 1, { x: 0, y: 0, depth: 1 }).scale, C.GROUP_SIZE);

const s = C.sizes(g);
eq("sizes: the source is exactly as big as the host's core, a copy smaller than a ring planet", [s.source, s.copy < g.bodySize, s.copy >= 12], [g.coreSize, true, true]);
eq("sizes: the source follows the core on any scene", [C.sizes(small).source, C.sizes({ cx: 0, cy: 0, rx: 400, ry: 250, coreSize: 90, bodySize: 60 }).source], [small.coreSize, 90]);
eq("sizes: the volume ring is outside the source, the orbit outside the ring", [s.ring > s.source / 2, s.radius - s.copy / 2 - s.ring >= 12], [true, true]);
const t = C.sizes(small);
eq("sizes: on a small scene the copies shrink and the orbit still fits", [t.copy < s.copy, t.copy >= 12, t.radius <= small.rx * 0.9], [true, true, true]);

// --- the copies' orbit ----------------------------------------------------------
const centre = C.groupAt(g, 0, slot);
const R = s.radius;
const slots = n => Array.from({ length: n }, (_, i) => C.copySlot(R, centre, i, n, 0.3));
for (const n of [1, 2, 3]) {
    const ring = slots(n);
    eq("orbit: " + n + " copies are on one ellipse around the source", round(ring.map(p => Math.hypot((p.x - centre.x) / R, (p.y - centre.y) / (R * C.TILT)))), Array(n).fill(1));
}
const three = slots(3);
const turn = i => Math.atan2((three[i].y - centre.y) / C.TILT, three[i].x - centre.x);
const gap = (a, b) => near(((turn(b) - turn(a)) + 4 * Math.PI) % (2 * Math.PI));
eq("orbit: three copies are equidistant (a third of a turn apart)", [gap(0, 1), gap(1, 2), gap(2, 0)], Array(3).fill(near(2 * Math.PI / 3)));
eq("orbit: four copies are a quarter of a turn apart", near(C.copySlot(R, centre, 1, 4, 0).x - centre.x), near(0));
eq("orbit: the near side has a positive depth, the far side a negative one", [C.copySlot(R, centre, 0, 4, Math.PI / 2).depth, C.copySlot(R, centre, 0, 4, -Math.PI / 2).depth], [1, -1]);
eq("orbit: a turn takes 25 s (the user-facing pace, written out so a change is deliberate)", C.PERIOD, 25);
eq("orbit: one turn takes 25 s and comes back to the start", [near(C.phaseAt(C.PERIOD) - C.phaseAt(0)), near(C.phaseAt(C.PERIOD / 4) - C.phaseAt(0))], [near(2 * Math.PI), near(Math.PI / 2)]);
eq("orbit: with the clock stopped the angles stay put", [C.copySlot(R, centre, 1, 3, C.phaseAt(5)), C.copySlot(R, centre, 1, 3, C.phaseAt(5))].every((p, _, a) => JSON.stringify(p) === JSON.stringify(a[0])), true);
const back = C.groupAt(g, 1, slot);
eq("orbit: a group that stepped back has a smaller orbit around its new centre", [Math.hypot(C.copySlot(R, back, 0, 2, 0).x - back.x, 0) < R, C.copySlot(R, back, 0, 2, 0).x > back.x], [true, true]);
eq("orbit: far side is a little smaller, never tiny", [C.depthSize(1), C.depthSize(0), C.depthSize(-1) >= 0.7], [1, 0.85, true]);

// --- the stacking order ---------------------------------------------------------
const body = (o) => Object.assign({ py: 200, depth: 0, inSlot: false, role: "" }, o);
eq("z: out of a group the far half of the ring passes behind the core, the rest sorts by height", [C.bodyZ(body({ inSlot: true, depth: -0.5 }), false, 0), C.bodyZ(body({ inSlot: true, depth: 0.5 }), false, 0), C.bodyZ(body({}), false, 0)], [10 + 2, 300, 300]);
eq("z: in a group everything sorts by height, the far half of the ring included, so the host (100 + y) sorts with it", [C.bodyZ(body({ inSlot: true, depth: -0.5, py: 150 }), true, 0), C.bodyZ(body({ inSlot: true, depth: -0.5, py: 250 }), true, 0)], [250, 350]);
eq("z: a member is where the group is, its source in the middle", [C.bodyZ(body({ role: "source", depth: 1, py: 10 }), true, 1300), C.bodyZ(body({ role: "source", depth: 1, py: 999 }), false, 1300)], [1300, 1300]);
eq("z: its copies over the source, near over far, whatever their height", [-1, -0.4, 0.4, 1].map(depth => C.bodyZ(body({ role: "copy", depth, py: 5 }), true, 1300)), [1300.25, 1300.4, 1300.6, 1300.75]);
eq("z: even the farthest copy is over the source, and none rises a whole level (nothing outside the group sorts between them)", [C.bodyZ(body({ role: "copy", depth: -1 }), true, 1300) > C.bodyZ(body({ role: "source" }), true, 1300), C.bodyZ(body({ role: "copy", depth: 1 }), true, 1300) < 1301], [true, true]);
eq("see through: a copy behind the source lets it show, whole on the near side, the source and a stranger always whole", [-1, -0.5, 0, 0.5, 1].map(d => near(C.seeThrough("copy", d, 1))).concat([C.seeThrough("source", -1, 1), C.seeThrough("", -1, 1)]), [0.58, 0.58, 0.58, 0.79, 1, 1, 1]);
eq("see through: it only takes hold as the device takes its place in the group", [0, 0.5, 1].map(mix => near(C.seeThrough("copy", -1, mix))), [1, 0.79, 0.58]);
eq("z: a body outside the group is behind it when the group is lifted over the system, and sorts with it otherwise", [C.bodyZ(body({ py: 400 }), true, 100 + 190 + 1000) < 100 + 190 + 1000, C.bodyZ(body({ py: 400 }), true, 100 + 190 + 40) > 100 + 190 + 40], [true, true]);

// --- the sky behind the camera --------------------------------------------------
eq("parallax: the sky drifts opposite to the camera, a fraction of the way", [C.parallax(g, { x: g.cx + 100, y: g.cy }).x < 0, C.parallax(g, { x: g.cx, y: g.cy + 100 }).y < 0], [true, true]);
eq("parallax: a source already at the centre moves nothing", C.parallax(g, { x: g.cx, y: g.cy }), { x: 0, y: 0 });
eq("parallax: never past the margin around the stars", [C.parallax(g, { x: g.cx + 9999, y: g.cy - 9999 }).x, C.parallax(g, { x: g.cx + 9999, y: g.cy - 9999 }).y], [-C.MAX_SHIFT, C.MAX_SHIFT]);

// --- who is who -----------------------------------------------------------------
const members = ["A", "B", "C"];
eq("roles: the source, the copies, and everyone else", [C.roleOf(members, "B", "B"), C.roleOf(members, "B", "A"), C.roleOf(members, "B", "Z")], ["source", "copy", ""]);
eq("copies: everyone but the source, in the order they joined", C.copiesOf(members, "B"), ["A", "C"]);
eq("copies: a new source changes who orbits, not the order", [C.copiesOf(members, "A"), C.copiesOf(members, "C")], [["B", "C"], ["A", "B"]]);

// --- the name under the centre --------------------------------------------------
eq("label: two members read 'XM6 + Marantz'", C.label(["XM6", "Marantz"]), "XM6 + Marantz");
eq("label: three short names are all there", C.label(["XM6", "Marantz", "Kitchen"]), "XM6 + Marantz + Kitchen");
eq("label: many or long names become +N", [C.label(["WH-1000XM6", "Marantz AV Receiver", "Kitchen speaker"]), C.label(["A", "B", "C", "D"]) === "A + B + C + D", C.label(["WH-1000XM6", "Marantz AV Receiver", "Kitchen speaker", "Bedroom"])], ["WH-1000XM6 + Marantz AV Receiver +1", true, "WH-1000XM6 + Marantz AV Receiver +2"]);
eq("label: a nameless member is left out", C.label(["XM6", "", "Marantz"]), "XM6 + Marantz");

// --- the pulse along a beam -----------------------------------------------------
eq("pulse: starts and ends dark, brightest half way", [C.pulse(0, 0, 2).alpha, near(C.pulse(2, 0, 2).alpha), C.pulse(0.5, 0, 2).at], [0, 0, 0.25]);
eq("pulse: the beams do not beat together", C.pulse(0, 0, 3).at !== C.pulse(0, 1, 3).at, true);
eq("pulse: always on its beam", [0, 1.3, 7.9, 100].every(time => C.pulse(time, 1, 3).at >= 0 && C.pulse(time, 1, 3).at < 1), true);

// --- the general volume (D284) --------------------------------------------------
eq("master: 50 % to 80 % takes 40 % to 64 % and 30 % to 48 %", round(V.scale([0.4, 0.3], 0.5, 0.8)), [0.64, 0.48]);
eq("master: going down keeps the gaps too", round(V.scale([0.64, 0.48], 0.8, 0.5)), [0.4, 0.3]);
eq("master: the ratio between members never changes", (() => { const r = V.scale([0.6, 0.2], 0.6, 0.3); return near(r[0] / r[1]); })(), 3);
eq("master: the general level is the loudest member", V.general([0.2, 0.9, 0.5]), 0.9);
eq("master: the loudest member reaches 100 % and nobody passes it", round(V.scale([0.9, 0.3], 0.9, 1)), [1, 0.333]);
eq("master: it cannot go higher than the loudest allows, so the gaps stay", [V.ceiling([0.4, 0.3], 0.5), V.ceiling([0.9, 0.3], 0.9)], [1.25, 1]);
eq("master: a request past the ceiling stops there", round(V.scale([0.8, 0.4], 0.5, 2)), [1, 0.5]);
eq("master: all silent, they all go to the level asked", V.scale([0, 0], 0, 0.4), [0.4, 0.4]);
eq("master: to zero silences everyone", V.scale([0.4, 0.3], 0.5, 0), [0, 0]);
eq("master: never below 0 or above 1", V.scale([1, 0.01], 1, -5).concat(V.scale([1, 0.01], 1, 5)), [0, 0, 1, 0.01]);
eq("master: one member alone is the general level itself", round(V.scale([0.7], 0.7, 0.2)), [0.2]);
eq("pointer: the ring reads 0 at the top and goes clockwise", [V.fromPointer(0, 0, 0, -10, 0.5), V.fromPointer(0, 0, 10, 0, 0.3), V.fromPointer(0, 0, 0, 10, 0.5), near(V.fromPointer(0, 0, -10, 0, 0.7))], [0, 0.25, 0.5, 0.75]);
eq("pointer: crossing the top stops at the end instead of jumping to the other", [V.fromPointer(0, 0, -1, -10, 0.1), V.fromPointer(0, 0, 1, -10, 0.9)], [0, 1]);
eq("pointer: with no reference (a fresh press) a click just left of the top reads near the end, just right near the start", [V.fromPointer(0, 0, -1, -10, NaN), V.fromPointer(0, 0, 1, -10, NaN)].map(v => Math.round(v * 100) / 100), [0.98, 0.02]);
eq("speaker: crossed out when muted, whatever the level", [V.icon(0.8, true), V.icon(0, true)], ["volume_off", "volume_off"]);
eq("speaker: empty at zero, one wave under half, two from half", [V.icon(0, false), V.icon(0.3, false), V.icon(0.49, false), V.icon(0.5, false), V.icon(1, false)], ["volume_mute", "volume_down", "volume_down", "volume_up", "volume_up"]);

// --- the name under the centre --------------------------------------------------
for (const [what, scene] of [["bar popout", g], ["small scene", small]]) {
    const z = C.sizes(scene);
    eq("label offset (" + what + "): under the ring and under the copies' lowest point", [C.labelOffset(z) > z.ring, C.labelOffset(z) > z.radius * C.TILT + z.copy / 2], [true, true]);
}

done();
