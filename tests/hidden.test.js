// The store of hidden devices: who is in it, how a device is put in or brought back, and what a hostile or broken store does.
// Run from the plugin root: gjs tests/hidden.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Hidden = load("Hidden.js");

const XM = "AA:BB:CC:DD:EE:01", AV = "AA:BB:CC:DD:EE:02";
const W1 = "alsa_output.usb-Acme_Pulse_Headset_0000-00.analog-stereo", W2 = "alsa_output.pci-0000_01_00.1.hdmi-stereo";

// --- Who is in it ---------------------------------------------------------------
const store = { [XM]: "Studio Headphones", [W1]: "Pulse Headset" };
eq("isHidden: a Bluetooth address and a wired output are both read", [XM, W1, AV, W2].map(id => Hidden.isHidden(store, id)), [true, true, false, false]);
eq("isHidden: a Bluetooth address is read in any spelling", [XM.toLowerCase(), XM.replace(/:/g, "_")].map(id => Hidden.isHidden(store, id)), [true, true]);
eq("isHidden: what an older version stored under its own spelling still counts", Hidden.isHidden({ [XM.toLowerCase()]: "x" }, XM.toLowerCase()), true);
eq("isHidden: nothing, junk or no store is nothing hidden", [Hidden.isHidden(store, ""), Hidden.isHidden(store, undefined), Hidden.isHidden(store, 5), Hidden.isHidden(store, "__proto__"), Hidden.isHidden(store, "constructor"), Hidden.isHidden(null, XM), Hidden.isHidden("x", XM), Hidden.isHidden([XM], XM)], Array(8).fill(false));

// --- Putting in and bringing back ---------------------------------------------------
eq("set: hides under the name it has", Hidden.set({}, XM, "Studio Headphones", true), { [XM]: "Studio Headphones" });
eq("set: stores the one spelling of the id, whatever it came as", Object.keys(Hidden.set({}, XM.toLowerCase(), "x", true)), [XM]);
eq("set: a name is cleaned and kept short, no name keeps the id", [Hidden.set({}, XM, "  Zero​width\n  name ", true)[XM], Hidden.set({}, XM, "x".repeat(100), true)[XM].length, Hidden.set({}, W1, "", true)[W1]], ["Zero width name", 40, W1]);
eq("set: a second device is added to the first", Object.keys(Hidden.set({ [XM]: "a" }, W1, "b", true)), [XM, W1]);
eq("set: hiding again renames, it is not a second entry", Hidden.set({ [XM]: "a" }, XM, "b", true), { [XM]: "b" });
eq("set: brings a device back, in whatever spelling it was stored", [Hidden.set(store, XM, "", false), Hidden.set({ [XM.toLowerCase()]: "x" }, XM, "", false)], [{ [W1]: "Pulse Headset" }, {}]);
eq("set: bringing back what is not there changes nothing", Hidden.set(store, AV, "", false), store);
eq("set: what is given is never changed", (() => { const before = JSON.stringify(store); Hidden.set(store, AV, "x", true); Hidden.set(store, XM, "", false); return JSON.stringify(store) === before; })(), true);
eq("set: a thing that is no output is not stored", ["x", "x; rm -rf /", "alsa_output..x", "", undefined, null, 5, { "a": 1 }].map(id => Object.keys(Hidden.set({}, id, "x", true)).length), Array(8).fill(0));

// --- The cap -------------------------------------------------------------------------
const full = {};
for (let i = 0; i < Hidden.MAX; i++)
    full["alsa_output.usb-Dock_" + i + "-00.analog-stereo"] = "n";
eq("the cap: a full store takes no one more, and says so", [Object.keys(Hidden.set(full, XM, "x", true)).length, Hidden.refusal(full, XM), Hidden.refusal({}, XM)], [Hidden.MAX, "full", ""]);
eq("the cap: one already in is not a new one, and a place frees up when one is brought back", [Hidden.refusal(full, Object.keys(full)[0]), Hidden.refusal(Hidden.set(full, Object.keys(full)[0], "", false), XM)], ["", ""]);
eq("the cap: something that is no output is refused before anything", [Hidden.refusal({}, "x"), Hidden.refusal(full, "x")], ["bad-id", "bad-id"]);

// --- Listing it ------------------------------------------------------------------------
eq("entries: by name without regard to case, then by id", Hidden.entries({ [XM]: "beta", [AV]: "Alpha", [W1]: "alpha" }), [{ "id": AV, "name": "Alpha" }, { "id": W1, "name": "alpha" }, { "id": XM, "name": "beta" }]);
eq("entries: a key that is no output is left out, a spelling is made the one", Hidden.entries({ "junk": "x", [XM.toLowerCase()]: "Low" }), [{ "id": XM, "name": "Low" }]);
eq("entries: no name falls back to the id, no store to nothing", [Hidden.entries({ [XM]: 5 }), Hidden.entries(null), Hidden.entries("x"), Hidden.entries([XM])], [[{ "id": XM, "name": "" }], [], [], []]);

// --- The Hidden section of the chooser: opens by itself once (D368) ----------------------
eq("sectionOpen: only a choice to open it opens it", [true, false, null, undefined, "yes", 1].map(Hidden.sectionOpen), [true, false, false, false, false, false]);
eq("opensAfterHide: never chosen, something got hidden: it opens", [null, undefined].map(p => Hidden.opensAfterHide(p, 0, 1)), [true, true]);
eq("opensAfterHide: nothing newly hidden (same count, or one brought back): no", [Hidden.opensAfterHide(null, 1, 1), Hidden.opensAfterHide(null, 2, 1), Hidden.opensAfterHide(null, 0, 0)], [false, false, false]);
eq("opensAfterHide: once chosen, either way, the choice is kept", [true, false].map(p => Hidden.opensAfterHide(p, 0, 1)), [false, false]);

done();
