// The long press: when it fires, how far it may drift, when its ring shows.
// Run from the plugin root: gjs tests/hold.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const H = load("Hold.js", ["HOLD_MS", "SLOP", "RING_AFTER_MS", "progress", "done", "ringVisible", "moved"]);

eq("the hold is half a second (D368)", H.HOLD_MS, 500);
eq("progress: 0 at the press, half way, full, never beyond", [H.progress(0), H.progress(250), H.progress(500), H.progress(900), H.progress(-5)], [0, 0.5, 1, 1, 0]);
eq("done: only once the 500 ms are over", [H.done(0), H.done(499), H.done(500), H.done(800)], [false, false, true, true]);
eq("the ring waits: a plain click never shows it", [H.ringVisible(0), H.ringVisible(119), H.ringVisible(120), H.ringVisible(400)], [false, false, true, true]);
eq("the ring shows well before a click could be a hold", H.RING_AFTER_MS < H.HOLD_MS, true);
eq("moved: inside the threshold it is still a hold, past it a drag", [H.moved({ x: 0, y: 0 }, { x: 3, y: 4 }), H.moved({ x: 0, y: 0 }, { x: 4, y: 4 }), H.moved({ x: 10, y: 10 }, { x: 10, y: 10 })], [false, true, false]);
eq("moved: either direction counts", [H.moved({ x: 0, y: 0 }, { x: -6, y: 0 }), H.moved({ x: 0, y: 0 }, { x: 0, y: -6 })], [true, true]);

done();
