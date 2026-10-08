// The nearest-PC rule of the new-device pop-up: strong, weak, below the floor, no reading, screen off, recent use.
// Run from the plugin root: gjs tests/nearestFilter.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Nearest = load("NearestFilter.js");
const d = Nearest.defaults;

// --- The wait from the signal alone ----------------------------------------------------
eq("at arm's reach: no wait", [Nearest.delayMs(-30), Nearest.delayMs(d.near)], [0, 0]);
eq("right at the floor: the longest wait", Nearest.delayMs(d.floor), d.maxDelayMs);
eq("halfway: half the wait", Nearest.delayMs((d.near + d.floor) / 2), d.maxDelayMs / 2);
eq("the wait grows as the signal falls", [-50, -60, -70].map(r => Nearest.delayMs(r)).every((v, i, a) => i === 0 || v > a[i - 1]), true);
eq("below the floor the wait stays at the longest", Nearest.delayMs(-95), d.maxDelayMs);
eq("a missing or invalid reading waits for nothing", [undefined, null, NaN, "-60", 0, 12, 127, -Infinity].map(r => Nearest.delayMs(r)), [0, 0, 0, 0, 0, 0, 0, 0]);
eq("limits can be given", Nearest.delayMs(-60, { "near": -40, "floor": -80, "maxDelayMs": 1000 }), 500);
eq("inverted or broken limits give no wait", [Nearest.delayMs(-60, { "near": -80, "floor": -40 }), Nearest.delayMs(-60, { "maxDelayMs": -5 }), Nearest.delayMs(-60, { "near": "x", "floor": NaN, "maxDelayMs": "y" })], [0, 0, Nearest.delayMs(-60)]);

// --- The decision ------------------------------------------------------------------------
const offer = (rssi, extra) => Nearest.shouldOffer(Object.assign({ "rssi": rssi }, extra));
eq("a strong signal opens at once", offer(-40), { "offer": true, "delayMs": 0, "reason": "nearest first" });
eq("a weak signal waits", offer(-70).delayMs > offer(-55).delayMs && offer(-55).delayMs > 0, true);
eq("just above the floor still offers", offer(d.floor).offer, true);
eq("below the floor: not here at all", offer(d.floor - 1), { "offer": false, "delayMs": 0, "reason": "below the signal floor" });
eq("no reading keeps today's behavior", [offer(undefined), offer(null), offer(0), offer(NaN)].map(r => [r.offer, r.delayMs]), [[true, 0], [true, 0], [true, 0], [true, 0]]);
eq("no context keeps today's behavior", [Nearest.shouldOffer(undefined).offer, Nearest.shouldOffer({}).delayMs], [true, 0]);
eq("a screen that is off gives way", offer(-60, { "screenOn": false }).delayMs, offer(-60).delayMs + d.tieMs);
eq("a PC in recent use goes first", offer(-60, { "recentUse": true }).delayMs, offer(-60).delayMs - d.tieMs);
eq("recent use never makes the wait negative", offer(-40, { "recentUse": true }).delayMs, 0);
eq("an unknown screen or use counts for nothing", offer(-60, { "screenOn": undefined, "recentUse": undefined }).delayMs, offer(-60).delayMs);
eq("a screen that is on adds nothing", offer(-60, { "screenOn": true }).delayMs, offer(-60).delayMs);
eq("an awake PC in use beats a nearer sleeping one", offer(-60, { "screenOn": true, "recentUse": true }).delayMs < offer(-50, { "screenOn": false }).delayMs, true);
eq("the signal still outweighs the tie-breakers", offer(-45, { "screenOn": false }).delayMs < offer(-70, { "recentUse": true }).delayMs, true);
eq("the screen and use do not rescue a device below the floor", offer(-90, { "screenOn": true, "recentUse": true }).offer, false);
eq("a sleeping PC without a reading still offers at once", offer(undefined, { "screenOn": false }).delayMs, 0);
eq("custom options reach the decision", offer(-62, { "opts": { "floor": -60 } }).offer, false);

done();
