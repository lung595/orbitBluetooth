// Which charging beam is drawn, and where its parts are (BeamStyle.js, BeamMotion.js).
// Run from the plugin root: gjs tests/beamStyle.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Style = load("BeamStyle.js", ["STYLES", "DEFAULT", "parse"]);
const Horizon = load("HorizonShape.js", ["bend", "pointAt", "controlAt", "grain", "ringRadius", "ringPoint", "knotAlpha", "tailAt", "GRAINS", "TAIL", "CAP", "RING_SCALE", "BEND_MAX"]);
const Motion = load("BeamMotion.js", ["pulseAt", "pulseAlpha", "deviceOffset", "chainWindow", "grainFront", "knotAngle", "PULSE_PERIOD", "PULSE_STILL", "CHAIN_STILL", "HORIZON_STILL_GRAIN", "HORIZON_STILL_KNOT", "HORIZON_FALL", "HORIZON_TURN"]);

eq("the four styles, in the order of the setting", Style.STYLES, ["pulse", "filament", "chain", "horizon"]);
eq("every listed style parses to itself", Style.STYLES.map(Style.parse), Style.STYLES);
eq("case and spaces are forgiven", [Style.parse(" Pulse "), Style.parse("HORIZON")], ["pulse", "horizon"]);
eq("an unknown, empty or missing value is Filament", [Style.parse("gauge"), Style.parse(""), Style.parse(null), Style.parse(undefined), Style.parse(3), Style.parse({})], Array(6).fill("filament"));
eq("the default is Filament", Style.DEFAULT, "filament");

// Pulse
eq("still frame: capsules at 1/6, 1/2 and 5/6", [0, 1, 2].map(i => Motion.pulseAt(12.3, false, i, 0.5)), [1 / 6, 1 / 2, 5 / 6]);
eq("the motion starts where the still frame is", [0, 1, 2].map(i => Motion.pulseAt(0, true, i, 0)), [1 / 6, 1 / 2, 5 / 6]);
eq("a capsule crosses the link in one period", Math.abs(Motion.pulseAt(Motion.PULSE_PERIOD, true, 0, 0) - 1 / 6) < 1e-9, true);
eq("a quarter period moves a capsule a quarter of the link", Math.abs(Motion.pulseAt(0.4, true, 0, 0) - (1 / 6 + 0.25)) < 1e-9, true);
eq("a delayed device is behind (negative time wraps into 0..1)", [Motion.pulseAt(0, true, 0, 0.5), Motion.pulseAt(0, true, 0, 5)].map(a => a >= 0 && a < 1), [true, true]);
eq("capsules fade at both ends and are clear in the middle", [Motion.pulseAlpha(0), Motion.pulseAlpha(0.075), Motion.pulseAlpha(0.5), Motion.pulseAlpha(1)], [0, 0.5, 1, 0]);
eq("the still capsules are visible", Motion.PULSE_STILL.every(a => Motion.pulseAlpha(a) > 0.5), true);

// Chain
const near = (a, b) => Math.abs(a - b) < 1e-9;
eq("Chain still: the window is frozen mid-link", Motion.chainWindow(9.9, false, 0.5), Motion.CHAIN_STILL);
eq("Chain still window is 30 % of the link, centred", [Motion.CHAIN_STILL[1] - Motion.CHAIN_STILL[0], (Motion.CHAIN_STILL[0] + Motion.CHAIN_STILL[1]) / 2].map(x => Math.round(x * 1e6) / 1e6), [0.3, 0.5]);
eq("Chain starts with no window at the host", Motion.chainWindow(0, true, 0), [0, 0]);
eq("Chain: the window grows out of the host end", (w => [w[0] === 0, w[1] > 0 && w[1] < 0.3])(Motion.chainWindow(0.2, true, 0)), [true, true]);
eq("Chain: mid-trip the window is whole (30 % of the link)", (w => near(w[1] - w[0], 0.3))(Motion.chainWindow(0.6, true, 0)), true);
eq("Chain: the window leaves at the device end", (w => [w[1], w[0] > 0.7])(Motion.chainWindow(1.15, true, 0)), [1, true]);
eq("Chain: the link rests 0.3 s between two windows", [Motion.chainWindow(1.3, true, 0), Motion.chainWindow(1.45, true, 0)], [[1, 1], [1, 1]]);
eq("Chain: it repeats every 1.5 s", Motion.chainWindow(0.6 + 1.5, true, 0).map(x => Math.round(x * 1e6)), Motion.chainWindow(0.6, true, 0).map(x => Math.round(x * 1e6)));
eq("Chain: always inside the link", [0, 0.3, 0.9, 1.2, 1.4, 7.7].every(t => Motion.chainWindow(t, true, 0.5).every(x => x >= 0 && x <= 1)), true);

// Horizon: clocks
eq("Horizon still: grain at 72 %, knot at 0.9 rad whatever the clock", [Motion.grainFront(5, false, 0.5), Motion.knotAngle(5, false, 0.5)], [0.72, 0.9]);
eq("Horizon motion starts where the still frame is", [Motion.grainFront(0, true, 0), Motion.knotAngle(0, true, 0)], [0.72, 0.9]);
eq("Horizon: a grain falls in 1.8 s, the knot turns in 3 s", [near(Motion.grainFront(Motion.HORIZON_FALL, true, 0), 0.72), near(Motion.knotAngle(Motion.HORIZON_TURN, true, 0), 0.9 + 2 * Math.PI)], [true, true]);
eq("Horizon: the grain front stays in 0..1", [0.1, 1, 1.7, 33].every(t => { const f = Motion.grainFront(t, true, 0.5); return f >= 0 && f < 1; }), true);

// Horizon: shapes
eq("the arc runs from the host to the device", [Horizon.pointAt(200, 0), Horizon.pointAt(200, 1)], [{ x: 0, y: -0 }, { x: 200, y: 0 }]);
eq("the arc bends 14 % of its length, 26 px at most", [Math.round(Horizon.bend(100) * 1e6) / 1e6, Horizon.bend(1000)], [14, 26]);
eq("the arc bends upward", Horizon.pointAt(200, 0.5).y < 0, true);
// A half of the arc is a quadratic Bezier of its own: evaluated at its middle it
// is the arc's point at a quarter (first half) or three quarters (second half)
eq("the first half of the arc is the arc", (c => [near(0.5 * c.x + 0.25 * Horizon.pointAt(200, 0.5).x, Horizon.pointAt(200, 0.25).x), near(0.5 * c.y + 0.25 * Horizon.pointAt(200, 0.5).y, Horizon.pointAt(200, 0.25).y)])(Horizon.controlAt(200, 0, 0.5)), [true, true]);
eq("the second half of the arc is the arc", (c => [near(0.25 * Horizon.pointAt(200, 0.5).x + 0.5 * c.x + 0.25 * 200, Horizon.pointAt(200, 0.75).x), near(0.25 * Horizon.pointAt(200, 0.5).y + 0.5 * c.y, Horizon.pointAt(200, 0.75).y)])(Horizon.controlAt(200, 0.5, 1)), [true, true]);
eq("a grain falls faster the nearer it is to the device", (g => g[3].x - g[2].x > g[1].x - g[0].x)([0.5, 0.6, 0.8, 0.9].map(f => Horizon.grain(200, f, 0))), true);
eq("trailing grains are behind, smaller and dimmer", (g => [g[1].x < g[0].x, g[5].r < g[0].r, g[5].alpha < g[0].alpha])([0, 1, 2, 3, 4, 5].map(k => Horizon.grain(200, 0.8, k))), [true, true, true]);
eq("a grain fades in at the host and out at the device", [Horizon.grain(200, 0, 0).alpha, Horizon.grain(200, 1, 0).alpha], [0.2, 0]);
eq("six grains and a tail of eight", [Horizon.GRAINS, Horizon.TAIL], [6, 8]);
eq("the ring is at most 1.3 times the device", Horizon.ringRadius(30), 39);
eq("the ring is seen almost edge-on", (p => [near(p.x, 39), near(Horizon.ringPoint(39, Math.PI / 2).y, 39 * 0.24)])(Horizon.ringPoint(39, 0)), [true, true]);
eq("the knot is full on the near side, half on the far side", [Horizon.knotAlpha(0.9), Horizon.knotAlpha(4)], [0.7, 0.35]);
eq("nothing lit passes 0.7 alpha", Horizon.CAP, 0.7);
eq("the tail fades out and follows the knot", [0, 7].map(k => Horizon.tailAt(39, 1, k)).map(t => Math.round(t.alpha * 1000) / 1000), [0.7, 0.088]);
eq("the tail trails behind the knot (smaller angle)", Math.abs(Horizon.tailAt(39, 1, 0).x - Horizon.ringPoint(39, 1).x) > 0, true);

// Phase offsets
eq("a device keeps its offset", Motion.deviceOffset("AA:BB:CC:DD:EE:01"), Motion.deviceOffset("AA:BB:CC:DD:EE:01"));
eq("offsets are whole steps of 0.5 s, under 2 s", ["AA:01", "AA:02", "AA:03", "AA:04", "x"].every(a => { const o = Motion.deviceOffset(a); return o >= 0 && o < 2 && o % 0.5 === 0; }), true);
eq("devices do not all share one offset", new Set(["AA:01", "AA:02", "AA:03", "AA:04", "AA:05", "AA:06"].map(Motion.deviceOffset)).size > 1, true);
eq("no address is no offset", [Motion.deviceOffset(""), Motion.deviceOffset(undefined)], [0, 0]);

done();
