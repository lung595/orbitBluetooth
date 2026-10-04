// Battery estimates and the card's lines (Charge.js, Endurance.js).
// Run from the plugin root: gjs tests/battery.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Charge = load("Charge.js", ["analyze", "formatShort", "timeText", "levelText", "statItems", "footnote"]);
const Endurance = load("Endurance.js", ["ratedHours"]);

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

done();
