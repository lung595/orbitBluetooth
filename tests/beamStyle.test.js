// Which charging beam is drawn, and where its parts are (BeamStyle.js, BeamMotion.js).
// Run from the plugin root: gjs tests/beamStyle.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Style = load("BeamStyle.js", ["STYLES", "DEFAULT", "DRAWN", "parse", "drawn"]);
const Motion = load("BeamMotion.js", ["pulseAt", "pulseAlpha", "deviceOffset", "PULSE_PERIOD", "PULSE_STILL"]);

eq("the four styles, in the order of the setting", Style.STYLES, ["pulse", "filament", "chain", "horizon"]);
eq("every listed style parses to itself", Style.STYLES.map(Style.parse), Style.STYLES);
eq("case and spaces are forgiven", [Style.parse(" Pulse "), Style.parse("HORIZON")], ["pulse", "horizon"]);
eq("an unknown, empty or missing value is Filament", [Style.parse("gauge"), Style.parse(""), Style.parse(null), Style.parse(undefined), Style.parse(3), Style.parse({})], Array(6).fill("filament"));
eq("the default is Filament", Style.DEFAULT, "filament");
eq("Pulse and Filament are drawn as themselves", [Style.drawn("pulse"), Style.drawn("filament")], ["pulse", "filament"]);
eq("Chain and Horizon fall back to Filament until they exist", [Style.drawn("chain"), Style.drawn("horizon")], ["filament", "filament"]);
eq("what cannot be drawn falls back too", Style.drawn("nope"), "filament");

// Pulse
eq("still frame: capsules at 1/6, 1/2 and 5/6", [0, 1, 2].map(i => Motion.pulseAt(12.3, false, i, 0.5)), [1 / 6, 1 / 2, 5 / 6]);
eq("the motion starts where the still frame is", [0, 1, 2].map(i => Motion.pulseAt(0, true, i, 0)), [1 / 6, 1 / 2, 5 / 6]);
eq("a capsule crosses the link in one period", Math.abs(Motion.pulseAt(Motion.PULSE_PERIOD, true, 0, 0) - 1 / 6) < 1e-9, true);
eq("a quarter period moves a capsule a quarter of the link", Math.abs(Motion.pulseAt(0.4, true, 0, 0) - (1 / 6 + 0.25)) < 1e-9, true);
eq("a delayed device is behind (negative time wraps into 0..1)", [Motion.pulseAt(0, true, 0, 0.5), Motion.pulseAt(0, true, 0, 5)].map(a => a >= 0 && a < 1), [true, true]);
eq("capsules fade at both ends and are clear in the middle", [Motion.pulseAlpha(0), Motion.pulseAlpha(0.075), Motion.pulseAlpha(0.5), Motion.pulseAlpha(1)], [0, 0.5, 1, 0]);
eq("the still capsules are visible", Motion.PULSE_STILL.every(a => Motion.pulseAlpha(a) > 0.5), true);

// Phase offsets
eq("a device keeps its offset", Motion.deviceOffset("AA:BB:CC:DD:EE:01"), Motion.deviceOffset("AA:BB:CC:DD:EE:01"));
eq("offsets are whole steps of 0.5 s, under 2 s", ["AA:01", "AA:02", "AA:03", "AA:04", "x"].every(a => { const o = Motion.deviceOffset(a); return o >= 0 && o < 2 && o % 0.5 === 0; }), true);
eq("devices do not all share one offset", new Set(["AA:01", "AA:02", "AA:03", "AA:04", "AA:05", "AA:06"].map(Motion.deviceOffset)).size > 1, true);
eq("no address is no offset", [Motion.deviceOffset(""), Motion.deviceOffset(undefined)], [0, 0]);

done();
