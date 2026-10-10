// The battery pills of the settings page (BatteryUse.js). Run from the plugin root: gjs tests/batteryUse.test.js
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const Use = load("BatteryUse.js");
const Index = load("SettingsIndex.js");
const read = f => new TextDecoder().decode(GLib.file_get_contents(root + "/" + f)[1]);

eq("three levels, as in Abyss", Object.values(Use.LEVELS), ["High battery use", "Some battery use", "Light on battery"]);
eq("every pill sits on a setting of the index", Object.keys(Use.USES).filter(k => !Index.ENTRIES.some(e => e.id === k)), []);
eq("every pill has a known level and a short reason", Object.entries(Use.USES).filter(([, u]) => !Use.LEVELS[u.level] || !u.why || u.why.length > 70).map(([k]) => k), []);
eq("a setting without a cost has no pill", Use.use("popupSize"), null);
eq("use() gives level, label and reason", Use.use("scopeFps").label, "Light on battery");

// Each listed setting shows its pill in its page, and only those do
const pages = ["Scanning", "Headphones", "Popup", "Desktop"].map(n => read("components/settings/" + n + "Page.qml")).join("\n");
const shown = [...pages.matchAll(/BatteryPill \{\s*forKey: "(\w+)"/g)].map(m => m[1]).sort();
eq("the pages carry exactly the listed pills", shown, Object.keys(Use.USES).sort());
eq("the old one-line battery note is gone", /batteryNote|Uses more battery/.test(pages + read("OrbitBluetoothSettings.qml")), false);
done();
