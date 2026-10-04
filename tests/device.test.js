// Device names and what may be looked up online (DeviceCatalog.js, Pictures.js).
// Run from the plugin root: gjs tests/device.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Anc = load("Anc.js", ["family", "nextMode", "ordered"]);
const Pictures = load("Pictures.js", ["queryFor", "creditText"]);
const Catalog = load("DeviceCatalog.js", ["deviceName", "modelName", "resolve"]);

// Rename: the alias is shown, but the device is still recognized by its own
// name (icon, noise control family)
const renamed = { address: "AA:BB:CC:DD:EE:FF", name: "My headset", deviceName: "WH-1000XM6", icon: "audio-headset" };
const original = { address: "AA:BB:CC:DD:EE:FF", name: "WH-1000XM6", deviceName: "WH-1000XM6", icon: "audio-headset" };
eq("renamed: shown name", Catalog.deviceName(renamed), "My headset");
eq("renamed: model name", Catalog.modelName(renamed), "WH-1000XM6");
eq("renamed: same kind", Catalog.resolve(renamed, {}), Catalog.resolve(original, {}));
eq("renamed: same ANC family", Anc.family(Catalog.modelName(renamed)), "sony");
eq("no own name: falls back to the alias", Catalog.modelName({ name: "Speaker", deviceName: "" }), "Speaker");

// Real pictures: what may be looked up online (only paired or connected devices, never a personal name)
eq("picture query: model", Pictures.queryFor("WH-1000XM6", true), "WH-1000XM6");
eq("picture query: suffix dropped", Pictures.queryFor("Galaxy Buds2 Pro (A1B2)", true), "Galaxy Buds2 Pro");
eq("picture query: not paired", Pictures.queryFor("Samsung QN90", false), "");
eq("picture query: possessive", Pictures.queryFor("Marie's iPhone", true), "");
eq("picture query: 'de' name", Pictures.queryFor("iPhone de Marie", true), "");
eq("picture query: address only", Pictures.queryFor("AA:BB:CC:DD:EE:FF", true), "");
eq("picture credit", Pictures.creditText({ title: "Sony", author: "Bob", license: "CC BY 4.0", source: "Wikimedia Commons" }), "“Sony” · by Bob · CC BY 4.0 · Wikimedia Commons");

done();
