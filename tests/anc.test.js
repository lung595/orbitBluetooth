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
const Palette = load("Palette.js", ["contrast", "ensureContrast", "onColor", "lift", "isGrey", "toHsl"]);
const Offer = load("Offer.js", ["scanBlocker", "isCandidate", "offerable", "headline", "features", "errorText"]);
const Pictures = load("Pictures.js", ["queryFor", "creditText"]);
const Catalog = load("DeviceCatalog.js", ["deviceName", "modelName", "resolve"]);
const Guard = load("Guard.js", ["offerFamily", "hasInput", "refused", "validPath", "parseUuids"]);

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

// Real pictures: what may be looked up online (only paired or connected devices, never a personal name)
eq("picture query: model", Pictures.queryFor("WH-1000XM6", true), "WH-1000XM6");
eq("picture query: suffix dropped", Pictures.queryFor("Galaxy Buds2 Pro (A1B2)", true), "Galaxy Buds2 Pro");
eq("picture query: not paired", Pictures.queryFor("Samsung QN90", false), "");
eq("picture query: possessive", Pictures.queryFor("Marie's iPhone", true), "");
eq("picture query: 'de' name", Pictures.queryFor("iPhone de Marie", true), "");
eq("picture query: address only", Pictures.queryFor("AA:BB:CC:DD:EE:FF", true), "");
eq("picture credit", Pictures.creditText({ title: "Sony", author: "Bob", license: "CC BY 4.0", source: "Wikimedia Commons" }), "“Sony” · by Bob · CC BY 4.0 · Wikimedia Commons");

// New device pop-up: when the background scan may run, what is offered
const ctx = { enabled: true, btOn: true, asleep: false, busy: false, audioConnected: false, onBattery: true, level: 50, minLevel: 30 };
eq("scan: allowed", Offer.scanBlocker(ctx), "");
eq("scan: low battery", Offer.scanBlocker(Object.assign({}, ctx, { level: 29 })), "battery below 30%");
eq("scan: low but plugged in", Offer.scanBlocker(Object.assign({}, ctx, { level: 10, onBattery: false })), "");
eq("scan: no battery", Offer.scanBlocker(Object.assign({}, ctx, { level: -1 })), "");
eq("scan: audio playing", Offer.scanBlocker(Object.assign({}, ctx, { audioConnected: true })), "audio device connected");
eq("scan: screen off", Offer.scanBlocker(Object.assign({}, ctx, { asleep: true })), "screen locked or off");
eq("offer: new headphones", Offer.isCandidate({ address: "A", name: "WH-1000XM6" }, "audio", {}), true);
eq("offer: paired", Offer.isCandidate({ address: "A", name: "WH-1000XM6", paired: true }, "audio", {}), false);
eq("offer: a phone", Offer.isCandidate({ address: "A", name: "Pixel 8" }, "phone", {}), false);
eq("offer: ignored", Offer.isCandidate({ address: "A", name: "WH-1000XM6" }, "audio", { A: "WH-1000XM6" }), false);
eq("offer: address only", Offer.isCandidate({ address: "A", name: "AA:BB:CC:DD:EE:FF" }, "audio", {}), false);
eq("offer: snoozed", Offer.offerable("A", { A: 2000 }, 1000), false);
eq("offer: snooze over", Offer.offerable("A", { A: 2000 }, 3000), true);
eq("headline: earbuds", Offer.headline("earbudsRound"), "New earbuds nearby");
eq("tiles: portable speaker charges", Offer.features({ family: "", hours: 0, kind: "speaker" }).map(t => t.value), ["Volume", "Charging"]);
eq("tiles: soundbar has no battery", Offer.features({ family: "", hours: 0, kind: "soundbar" }).map(t => t.value), ["Volume"]);
eq("tiles: headphones", Offer.features({ family: "sony", hours: 30, kind: "headphonesSlim" }).map(t => t.value), ["Noise control", "≈ 30 h", "Volume"]);
eq("error: declined", Offer.errorText("org.bluez.Error.AuthenticationRejected"), "The pairing was declined.");
eq("error: timeout", Offer.errorText("Page Timeout"), "No answer. Is it still in pairing mode?");
eq("error: unknown", Offer.errorText(""), "Could not connect. Is it still in pairing mode?");

// Pairing sheet colours: any accent reads on either skin
const hex = h => ({ r: parseInt(h.slice(1, 3), 16) / 255, g: parseInt(h.slice(3, 5), 16) / 255, b: parseInt(h.slice(5, 7), 16) / 255 });
const night = hex("#0A0C14"), pearl = hex("#E6E8EF");
for (const accent of ["#F2B8C6", "#1A3A8F", "#C5E66A", "#4B6818", "#00FFD1", "#BDBDBD"]) {
    eq("readable on night: " + accent, Palette.contrast(Palette.ensureContrast(hex(accent), night, 6), night) >= 6, true);
    eq("readable on pearl: " + accent, Palette.contrast(Palette.ensureContrast(hex(accent), pearl, 4.5), pearl) >= 4.5, true);
    const fill = Palette.ensureContrast(hex(accent), pearl, 4.5);
    eq("button ink: " + accent, Palette.contrast(Palette.onColor(fill), fill) >= 4.5, true);
}
eq("hue kept when fixed", Math.round(Palette.toHsl(Palette.ensureContrast(hex("#F2B8C6"), pearl, 4.5)).h * 100), Math.round(Palette.toHsl(hex("#F2B8C6")).h * 100));
eq("lift", Math.round(Palette.toHsl(Palette.lift(hex("#4B6818"), 0.66)).l * 100), 66);
eq("grey", Palette.isGrey(hex("#BDBDBD")), true);

// Pairing guard (P115): a fake "headset" that can type is refused
const HID = "00001124-0000-1000-8000-00805f9b34fb", HOG = "00001812-0000-1000-8000-00805F9B34FB", A2DP = "0000110b-0000-1000-8000-00805f9b34fb";
eq("offer: audio class", Guard.offerFamily("audio-headset"), "audio");
eq("offer: no class, headset name is not enough", Guard.offerFamily(""), "");
eq("offer: keyboard class", Guard.offerFamily("input-keyboard"), "");
eq("refuse: headset with HID", Guard.refused("audio", [A2DP, HID]), true);
eq("refuse: headset with HID over LE (upper case)", Guard.refused("audio", [HOG]), true);
eq("refuse: unknown family with HID", Guard.refused("", [HID]), true);
eq("allow: real headset", Guard.refused("audio", [A2DP]), false);
eq("allow: real keyboard", Guard.refused("keyboard", [HID]), false);
eq("allow: real mouse", Guard.refused("pointer", [HOG]), false);
eq("path ok", Guard.validPath("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"), true);
eq("path: injection", Guard.validPath("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF; rm"), false);
eq("path: option", Guard.validPath("--help"), false);
eq("path: empty", Guard.validPath(undefined), false);
eq("uuids parsed", Guard.parseUuids('{"type":"as","data":["0000110B-x"]}'), ["0000110b-x"]);
eq("uuids: garbage", Guard.parseUuids("nope"), null);
eq("uuids: wrong type", Guard.parseUuids('{"type":"s","data":"x"}'), null);

print(failures ? failures + "/" + count + " failed" : count + " tests passed");
imports.system.exit(failures ? 1 : 0);
