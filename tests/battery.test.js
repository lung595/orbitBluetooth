// Battery estimates and the card's lines (Charge.js, Endurance.js).
// Run from the plugin root: gjs tests/battery.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Charge = load("Charge.js", ["analyze", "formatShort", "timeText", "levelText", "statItems", "footnote", "levelColor"]);
const Endurance = load("Endurance.js", ["ratedHours"]);
const Battery = load("Battery.js", ["CRITICAL_MAX", "LOW_AT", "stretch", "along", "hueMix"]);

// Time left: rated life at first, then the measured drain takes over
const now = Date.UTC(2026, 8, 26, 12, 0, 0);
const rated = Endurance.ratedHours("WH-1000XM6", "headphones", "nc");
eq("rated XM6 cancelling", rated, 30);
eq("rated XM6 off", Endurance.ratedHours("WH-1000XM6", "headphones", "off"), 40);
eq("rated unknown mouse", Endurance.ratedHours("MX Master 3S", "mouse", ""), 0);
const first = Charge.analyze([[now - 60000, 80]], 80, null, now, rated);
eq("first estimate source", first.source, "rated");
eq("first estimate", Charge.formatShort(first.minutesLeft), "24h00");
const early = Charge.analyze([[now - 10 * 60000, 90], [now, 80]], 80, null, now, rated);
eq("a 10% step 10 min in stays close to the rated life", early.minutesLeft > 18 * 60, true);
const late = Charge.analyze([[now - 180 * 60000, 90], [now, 60]], 60, null, now, rated);
eq("after 3 h the measure wins", Charge.formatShort(late.minutesLeft), "6h00");
eq("days", Charge.formatShort(3 * 1440), "3d");

// The card's lines and tiles: "≈" only on an estimate, nothing made up
const drain = { source: "rated", minutesLeft: 90, ratePerHour: -12, health: 0 };
const fill = { source: "system", minutesToFull: 30, fullAt: now + 30 * 60000, watts: 0, ratePerHour: 40, gained: 8, since: now - 20 * 60000, health: 92 };
eq("time left, estimated", Charge.timeText(drain, false), "≈ 1 h 30 left");
eq("time to full, reported", Charge.timeText(fill, true), "30 min to full");
eq("charging, no speed yet", Charge.timeText({ source: "estimated" }, true), "Measuring…");
eq("draining, no figure", Charge.timeText({ source: "estimated" }, false), "");
eq("level line, draining", Charge.levelText(60, drain, false), "60%  •  ≈ 1 h 30 left");
eq("level line, charging", Charge.levelText(80, fill, true), "80%  •  Full in 30 min");
eq("level line, unknown", Charge.levelText(40, null, false), "40%");
eq("tiles, draining", Charge.statItems(drain, false, now).map(t => t.label).join(","), "EMPTY AT,DRAIN");
const tiles = Charge.statItems(fill, true, now);
eq("tiles, charging", tiles.map(t => t.label).join(","), "READY AT,SPEED,+8% IN,HEALTH");
eq("tiles, charging values", tiles.slice(1).map(t => t.value).join(","), "+40 %/h,20 min,92%");
eq("ready at, reported: no ≈", tiles[0].value.startsWith("≈"), false);
eq("tiles, full", Charge.statItems({ source: "system", state: "full", health: 0 }, false, now).length, 0);
eq("footnote, reported", Charge.footnote(fill, true), "Reported by the device");
eq("footnote, rated", Charge.footnote(drain, false), "From the rated battery life · refines as it drains");

// The arc around a disc: a colour that drifts with the level (red, amber, green), its own look while charging
const stretchAt = (l, charging) => Battery.stretch(l, charging || false);
eq("charging is its own tone, whatever the level", [100, 40, 15, 0].map(l => stretchAt(l, true)), Array(4).fill({ from: "charging", to: "charging", t: 0 }));
eq("15 % and down is plain red", [15, 5, 0].map(l => stretchAt(l)), Array(3).fill({ from: "critical", to: "critical", t: 0 }));
eq("from red toward amber, amber reached at 35 %", [16, 25, 35].map(l => stretchAt(l)), [{ from: "critical", to: "low", t: 0.05 }, { from: "critical", to: "low", t: 0.5 }, { from: "critical", to: "low", t: 1 }]);
eq("from amber toward green, green reached at 100 %", [36, 67.5, 100].map(l => stretchAt(l).to + ":" + Math.round(stretchAt(l).t * 1000)), ["ok:15", "ok:500", "ok:1000"]);
eq("above 35 % it starts from amber", stretchAt(36).from, "low");
eq("a level out of range is held to the ends", [stretchAt(-4), stretchAt(140)], [{ from: "critical", to: "critical", t: 0 }, { from: "low", to: "ok", t: 1 }]);
eq("the amber is the same seen from both sides of 35 %", [stretchAt(Battery.LOW_AT).to, stretchAt(Battery.LOW_AT + 1).from], ["low", "low"]);
// Where a level lies on the red-amber-green line (0..2): it climbs with the level, one point
// never jumps it by more than the steepest stretch does, where three steps would jump by a whole tone
const rank = { "critical": 0, "low": 1, "ok": 2 };
const spot = l => { const s = stretchAt(l); return rank[s.from] + (s.to === s.from ? 0 : s.t); };
const spots = Array.from({ length: 101 }, (_, l) => spot(l));
const gaps = spots.slice(1).map((v, i) => v - spots[i]);
eq("the colour never goes back as the level climbs", gaps.every(g => g >= 0), true);
eq("and never jumps: no step is bigger than one point of the steepest stretch", gaps.every(g => g <= 1 / (Battery.LOW_AT - Battery.CRITICAL_MAX) + 1e-9), true);
eq("the line runs from red to green", [spots[0], spots[100]], [0, 2]);
const round3 = v => Math.round(v * 1000) / 1000;
eq("along: a share of the way from one number to another", [Battery.along(10, 20, 0), Battery.along(10, 20, 0.25), Battery.along(1, 0, 1)], [10, 12.5, 0]);
eq("hueMix: straight when the short way is", [round3(Battery.hueMix(0, 0.12, 0.5)), round3(Battery.hueMix(0.3, 0.1, 0.5))], [0.06, 0.2]);
eq("hueMix: a red just under the wheel's end and an amber just past it meet through orange, not cyan", [0, 0.5, 1].map(t => round3(Battery.hueMix(0.98, 0.1, t))), [0.98, 0.04, 0.1]);
eq("hueMix: a grey has no hue, the other one's is kept", [Battery.hueMix(-1, 0.3, 0.5), Battery.hueMix(0.3, -1, 0.5)], [0.3, 0.3]);
eq("the card's ramp stays red as long as the arc does", [Charge.levelColor(0), Charge.levelColor(Battery.CRITICAL_MAX), Charge.levelColor(Battery.CRITICAL_MAX + 1) !== Charge.levelColor(0)], ["#ff5468", "#ff5468", true]);

done();
