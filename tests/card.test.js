// The detail card's wording: kind line, status icon, status and detail lines (CardStatus.js).
// Run from the plugin root: gjs tests/card.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Charge = load("Charge.js", ["levelText"]);
const CardStatus = load("CardStatus.js", ["kindLine", "statusIcon", "statusText", "detailText"]);

// Battery estimates the lines are built from (same shapes as tests/battery.test.js)
const now = Date.UTC(2026, 8, 26, 12, 0, 0);
const drain = { source: "rated", minutesLeft: 90, ratePerHour: -12, health: 0 };
const fill = { source: "system", minutesToFull: 30, fullAt: now + 30 * 60000, watts: 0, ratePerHour: 40, gained: 8, since: now - 20 * 60000, health: 92 };

const body = (o) => Object.assign({ kind: "headphones", connected: false, paired: false, charging: false, phase: "idle" }, o);
eq("kind line, connected", CardStatus.kindLine(body({ connected: true, paired: true })), "Over-ear  ·  Connected");
eq("kind line, paired", CardStatus.kindLine(body({ paired: true })), "Over-ear  ·  Paired");
eq("kind line, nearby", CardStatus.kindLine(body({})), "Over-ear  ·  Available");
eq("kind line, no body", CardStatus.kindLine(null), "");
eq("status icon: connecting wins over charging", CardStatus.statusIcon(body({ phase: "connecting", charging: true }), null), "sync");
eq("status icon: charging", CardStatus.statusIcon(body({ connected: true, charging: true }), null), "bolt");
eq("status icon: full", CardStatus.statusIcon(body({ connected: true }), { state: "full" }), "battery_full");
eq("status icon: connected, paired, none", ["connected", "paired", "none"].map((k, i) => CardStatus.statusIcon(body({ connected: i === 0, paired: i < 2 }), null)), ["bluetooth_connected", "bluetooth", "bluetooth"]);
eq("status icon: no body", CardStatus.statusIcon(null, null), "bluetooth");
eq("status: phases", ["connecting", "disconnecting"].map(p => CardStatus.statusText(body({ phase: p, connected: true }), null, 0, 0)), ["Connecting...", "Disconnecting..."]);
eq("status: charging", CardStatus.statusText(body({ connected: true, charging: true }), { state: "charging" }, 0, 0), "Charging...");
eq("status: full", CardStatus.statusText(body({ connected: true }), { state: "full" }, 0, 0), "Fully charged");
eq("status: connected, since unknown", CardStatus.statusText(body({ connected: true }), null, 0, 5000), "Connected");
eq("status: connected for a while", CardStatus.statusText(body({ connected: true }), null, 1000, 1000 + 90 * 60000), "Connected for 1:30:00");
eq("status: paired or available", [true, false].map(p => CardStatus.statusText(body({ paired: p }), null, 0, 0)), ["Not connected", "Available nearby"]);
eq("status: no body", CardStatus.statusText(null, null, 0, 0), "");
eq("detail: level and time", CardStatus.detailText(body({ connected: true }), drain, 60), Charge.levelText(60, drain, false));
eq("detail: charging uses the charging line", CardStatus.detailText(body({ connected: true, charging: true }), fill, 80), Charge.levelText(80, fill, true));
eq("detail: connected, no battery", CardStatus.detailText(body({ connected: true }), null, -1), "No battery info");
eq("detail: signal", CardStatus.detailText(body({ rawSignal: 0.456 }), null, -1), "Signal 46%");
eq("detail: out of range", CardStatus.detailText(body({ rawSignal: 0 }), null, -1), "Out of range");
eq("detail: no body", CardStatus.detailText(null, null, -1), "");

done();
