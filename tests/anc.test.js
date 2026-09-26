// Pure-logic tests for components/Anc.js, Charge.js and Endurance.js.
// Run from the plugin root: gjs tests/anc.test.js
const GLib = imports.gi.GLib;

const root = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/anc.test.js", GLib.get_current_dir())));

// QML ".pragma library" files are plain JS once the pragma is removed
function load(file, names) {
    const [, bytes] = GLib.file_get_contents(root + "/components/" + file);
    const src = new TextDecoder().decode(bytes).replace(".pragma library", "");
    return new Function(src + "; return { " + names.join(", ") + " };")();
}

const Anc = load("Anc.js", ["family", "nextMode", "ordered"]);
const Charge = load("Charge.js", ["analyze", "formatShort"]);
const Endurance = load("Endurance.js", ["ratedHours"]);
const Catalog = load("DeviceCatalog.js", ["deviceName", "modelName", "resolve"]);

let count = 0, failures = 0;
function eq(what, got, expected) {
    count++;
    if (JSON.stringify(got) !== JSON.stringify(expected)) {
        failures++;
        print("✗ " + what + "\n    expected: " + JSON.stringify(expected) + "\n    got:      " + JSON.stringify(got));
    }
}

// Brand detection by Bluetooth name
const names = {
    "WH-1000XM6": "sony", "WF-1000XM5": "sony", "LinkBuds S": "sony",
    "AirPods Pro": "apple", "Beats Studio Pro": "apple",
    "Nothing Ear (2)": "nothing", "CMF Buds Pro 2": "nothing",
    "Galaxy Buds2 Pro (A1B2)": "samsung", "Buds3 Pro": "samsung",
    "Bose QC35 II": "bose", "Bose QC Ultra Headphones": "bose",
    "Soundcore Life Q30": "soundcore", "Soundcore Space Q45": "soundcore",
    "HUAWEI FreeBuds Pro 3": "huawei", "HONOR Earbuds 2 Lite": "huawei", "HUAWEI FreeLace Pro": "huawei",
    "realme Buds Air6 Pro": "oppo", "OPPO Enco Air2": "oppo", "OnePlus Buds Pro 2": "oppo",
    "Redmi Buds 5 Pro": "xiaomi", "REDMI Buds 8 Active": "xiaomi",
    "EarFun Air Pro 4": "earfun", "Space Travel 2 Ultra": "moondrop",
    "HAYLOU S35 ANC": "haylou", "1MORE SonoFlow SE": "onemore",
    // Never sent vendor commands: unknown, unsupported or no noise control
    "MX Master 3S": "", "Xbox Wireless Controller": "", "JBL Tune 770NC": "", "Jabra Elite 85t": "",
    "EarFun Free 2": "", "": ""
};
for (const n in names)
    eq("family(" + JSON.stringify(n) + ")", Anc.family(n), names[n]);

// Mode order and cycling (right-click menu, IPC ancCycle)
eq("ordered", Anc.ordered(["off", "ambient", "nc"]), ["nc", "ambient", "off"]);
eq("next skips off", Anc.nextMode(["nc", "ambient", "off"], "ambient"), "nc");
eq("next from unknown", Anc.nextMode(["nc", "ambient", "off"], null), "nc");
eq("next with only on/off", Anc.nextMode(["nc", "off"], "nc"), "off");

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


// Rename: the alias is shown, but the device is still recognized by its own
// name (icon, noise control family)
const renamed = { address: "AA:BB:CC:DD:EE:FF", name: "My headset", deviceName: "WH-1000XM6", icon: "audio-headset" };
const original = { address: "AA:BB:CC:DD:EE:FF", name: "WH-1000XM6", deviceName: "WH-1000XM6", icon: "audio-headset" };
eq("renamed: shown name", Catalog.deviceName(renamed), "My headset");
eq("renamed: model name", Catalog.modelName(renamed), "WH-1000XM6");
eq("renamed: same kind", Catalog.resolve(renamed, {}), Catalog.resolve(original, {}));
eq("renamed: same ANC family", Anc.family(Catalog.modelName(renamed)), "sony");
eq("no own name: falls back to the alias", Catalog.modelName({ name: "Speaker", deviceName: "" }), "Speaker");

print(failures ? failures + "/" + count + " failed" : count + " tests passed");
imports.system.exit(failures ? 1 : 0);
