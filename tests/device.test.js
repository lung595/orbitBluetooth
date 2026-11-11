// Device names and how a renamed device is still recognized (DeviceCatalog.js).
// Run from the plugin root: gjs tests/device.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Anc = load("Anc.js", ["family", "nextMode", "ordered"]);
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

done();
