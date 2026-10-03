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
const Guide = load("Guide.js", ["url", "connectNote", "blockedNote", "noVolumeNote", "stuckNote", "levelNote"]);
const Volume = load("Volume.js", ["start", "sweep", "clamp", "step", "nudge", "valueAt", "zone", "findSink", "validSink"]);
const Fx = load("VolumeFx.js", ["clamp01", "ripple", "band", "filament", "emission", "spawn", "step", "lifeT", "follow", "wave"]);
const Guard = load("Guard.js", ["offerFamily", "hasInput", "refused", "validPath", "parseUuids"]);
const Cover = load("Cover.js", ["covered"]);
const Polar = load("Polar.js", ["LEFT", "TOP", "RIGHT", "arc", "end", "point", "angleOf", "valueAt", "zone", "parseFrame", "loudness", "spawn", "cavaConfig"]);
const Route = load("Route.js", ["addressKey", "virtualName", "isVirtual", "addressOfVirtual", "isDeviceSink", "addressOfSink", "deviceSink", "virtualSink", "description", "filterArgs", "muteTarget", "ipcLevel", "transportPath", "transportVolume", "iconFor", "popupSize"]);

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

// Guide links (value 10): every anchor used must exist in docs/GUIDE.md
const GLibG = imports.gi.GLib;
const guide = new TextDecoder().decode(GLibG.file_get_contents(GLibG.build_filenamev([GLibG.path_get_dirname(GLibG.path_get_dirname(imports.system.programPath ?? "tests/anc.test.js")), "docs", "GUIDE.md"]))[1]);
const anchors = guide.split("\n").filter(l => /^#{2,3} /.test(l)).map(l => l.replace(/^#+ /, "").toLowerCase().replace(/[^a-z0-9 -]/g, "").replace(/ /g, "-"));
["pair", "check", "connect"].forEach(why => {
    const n = Guide.connectNote(why, "Momentum 4");
    eq("note " + why + " has a title and a hint", !!(n.title && n.hint), true);
    eq("note " + why + " links to a real section", anchors.indexOf(n.anchor) >= 0, true);
});
[Guide.blockedNote(), Guide.noVolumeNote("K380"), Guide.stuckNote("Momentum 4")].forEach(n => {
    eq("note \"" + n.title + "\" has a hint", !!n.hint, true);
    eq("note \"" + n.title + "\" links to a real section", anchors.indexOf(n.anchor) >= 0, true);
});
eq("a nameless device has no volume", Guide.noVolumeNote("").title, "This device has no volume");
eq("a nameless device stuck", Guide.stuckNote("").title, "This device is still connected");
["noise-control", "pairing-safety", "if-it-does-not-connect", "if-it-does-not-disconnect", "bluetooth-is-off", "volume-ring", "new-headphones-pop-up"].forEach(a => eq("guide has #" + a, anchors.indexOf(a) >= 0, true));
eq("guide url", Guide.url("noise-control"), "https://github.com/lung595/orbitBluetooth/blob/main/docs/GUIDE.md#noise-control");
eq("a nameless device", Guide.connectNote("pair", "").title, "Could not pair this device");

// --- Volume ring ---------------------------------------------------------------
eq("wheel up lands on the 5 % grid", Volume.nudge(0.62, 1), 0.65);
eq("wheel down", Math.round(Volume.nudge(0.6, -2) * 100), 50);
eq("never above 100 %", Volume.nudge(0.98, 3), 1);
eq("never below 0 %", Volume.nudge(0.02, -3), 0);
eq("same step: no tick", Volume.step(0.61) === Volume.step(0.62), true);
eq("next step: tick", Volume.step(0.62) === Volume.step(0.68), false);
eq("top of the ring is half", Math.round(Volume.valueAt(0, -100, 0.3) * 100), 50);
eq("start of the ring is 0", Math.round(Volume.valueAt(Math.cos(Math.PI * 2 / 3) * 100, Math.sin(Math.PI * 2 / 3) * 100, 0.5) * 100), 0);
eq("gap keeps a high level at 100 %", Volume.valueAt(0, 100, 0.9), 1);
eq("gap keeps a low level at 0 %", Volume.valueAt(0, 100, 0.1), 0);
eq("on the ring", Volume.zone(0, -60, 60, 45), "ring");
eq("on the glyph", Volume.zone(5, 5, 60, 45), "glyph");
eq("outside", Volume.zone(0, -90, 60, 45), "");
const nodes = [
    { name: "alsa_output.pci-0000_00_1f.3", isSink: true, isStream: false },
    { name: "bluez_output.02_00_00_00_10_06.1", isSink: true, isStream: true },
    { name: "bluez_output.02_00_00_00_10_06.1", isSink: true, isStream: false }
];
eq("sink found by address", Volume.findSink(nodes, "02:00:00:00:10:06"), nodes[2]);
eq("no sink, no ring", Volume.findSink(nodes, "02:00:00:00:10:07"), null);
eq("bad address", Volume.findSink(nodes, "02:00"), null);
eq("node name ok for pw-play", Volume.validSink("bluez_output.02_00_00_00_10_06.1"), true);
eq("no shell characters", Volume.validSink("x; rm -rf ~"), false);
eq("no option smuggling", Volume.validSink("--target=x y"), false);

// Volume ring effects (VolumeFx.js)
eq("no aurora at 0 %", Fx.band(100, 100, 40, 6, 120, 300, 0, 0, 2), []);
const aurora = Fx.band(100, 100, 40, 6, 120, 300, 0.5, 1.3, 2);
eq("aurora is a closed ribbon (outer + inner edge)", aurora.length % 2, 0);
eq("aurora stays near the ring", aurora.every(p => Math.abs(Math.hypot(p.x - 100, p.y - 100) - 40) < 3 + 2 * 1.5 + 0.01), true);
const calm = Fx.band(100, 100, 40, 6, 120, 300, 0.5, 1.3, 0);
eq("still aurora: outer edge outside, inner inside", Math.hypot(calm[1].x - 100, calm[1].y - 100) > 40 && Math.hypot(calm[calm.length - 2].x - 100, calm[calm.length - 2].y - 100) < 40, true);
eq("aurora ends where the level is", Math.round(Math.atan2(calm[calm.length / 2 - 1].y - 100, calm[calm.length / 2 - 1].x - 100) * 180 / Math.PI), 270 - 360);
eq("filament follows the level", Fx.filament(0, 0, 40, 120, 300, 1, 0, 0).length > 50, true);
eq("ripple is bounded", [0, 50, 123, 300].every(d => Math.abs(Fx.ripple(d, 2.2)) <= 1.5), true);
eq("still moon emits no dust", Fx.emission(0, 0.016, 0).count, 0);
let slow = { carry: 0, count: 0 }, slowGrains = 0;
for (let i = 0; i < 12; i++) { slow = Fx.emission(30, 1 / 60, slow.carry); slowGrains += slow.count; }
eq("a slow move still emits, over a few frames", slowGrains, 4);
let carry = 0, grains = 0;
for (let i = 0; i < 60; i++) { const e = Fx.emission(1000, 1 / 60, carry); carry = e.carry; grains += e.count; }
// Float carry can land one grain short over a second, so the cap is a bound, not an exact count.
eq("a wild drag is capped at 80 grains a second", grains <= 80 && grains >= 79, true);
const grain = Fx.spawn(100, 100, 40, 0, 1, 0.5, 0.5, 0.5, 0.5);
eq("grain is born on the moon", [Math.round(grain.x), Math.round(grain.y)], [140, 100]);
eq("going up throws it ahead (down on the right side) and outward", grain.vy > 0 && grain.vx > 0, true);
eq("going down throws it the other way", Fx.spawn(100, 100, 40, 0, -1, 0.5, 0.5, 0.5, 0.5).vy < 0, true);
const g = Fx.spawn(100, 100, 40, 0, 1, 0.5, 0, 0.5, 0.5);
let alive = true, steps = 0;
while (alive && steps < 1000) { alive = Fx.step(g, 1 / 60, 100, 100, 140); steps++; }
eq("grain fades within its life", steps, Math.ceil(g.life * 60));
eq("gravity pulls it toward the planet", Math.hypot(g.x - 100, g.y - 100) < 60, true);
eq("life goes 0 to 1", [Fx.lifeT({ age: 0, life: 1 }), Fx.lifeT({ age: 2, life: 1 })], [0, 1]);
// The comet tail closes on the moon without overshooting, faster with time
eq("tail stays put with no time", Math.abs(Fx.follow(0.2, 0.8, 0, 9) - 0.2) < 1e-9, true);
eq("tail moves toward the moon", Fx.follow(0.2, 0.8, 0.05, 9) > 0.2 && Fx.follow(0.2, 0.8, 0.05, 9) < 0.8, true);
eq("tail has caught up after a second", Math.abs(Fx.follow(0.2, 0.8, 1, 9) - 0.8) < 0.001, true);
eq("two half frames = one frame", Math.abs(Fx.follow(Fx.follow(0.2, 0.8, 0.02, 9), 0.8, 0.02, 9) - Fx.follow(0.2, 0.8, 0.04, 9)) < 1e-9, true);
const w0 = Fx.wave(30, 0.5, false, 0), w1 = Fx.wave(30, 0.5, false, 1);
eq("wave leaves the planet edge", w0.radius, 30);
eq("wave fades out", w1.alpha, 0);
eq("louder = wider wave", Fx.wave(30, 1, false, 1).radius > Fx.wave(30, 0.2, false, 1).radius, true);
eq("corona goes further", Fx.wave(30, 1, true, 1).radius > Fx.wave(30, 1, false, 1).radius, true);

// Ambient motion pauses on a screen hidden behind windows (P123).
// Made-up layout: three screens, sizes in logical pixels.
const spaces = {
    1: { id: 1, output: "OUT-1", is_active: true },
    2: { id: 2, output: "OUT-1", is_active: false },
    3: { id: 3, output: "OUT-2", is_active: true },
    4: { id: 4, output: "OUT-3", is_active: true }
};
const tile = (ws, col, w, h, floating) => ({ workspace_id: ws, is_floating: !!floating, layout: { tile_size: [w, h], pos_in_scrolling_layout: [col, 1] } });
const W = 2560, H = 1440;
eq("fullscreen window covers its screen", Cover.covered(spaces, [tile(1, 1, W, H)], "OUT-1", W, H, false), true);
eq("maximized column (gaps, bar) covers", Cover.covered(spaces, [tile(1, 1, 2528, 1388)], "OUT-1", W, H, false), true);
eq("two columns side by side fill the screen", Cover.covered(spaces, [tile(1, 1, 846, 1388), tile(1, 2, 1697, 1388)], "OUT-1", W, H, false), true);
eq("two stacked windows make one full-height column", Cover.covered(spaces, [tile(1, 1, 2528, 690), { workspace_id: 1, layout: { tile_size: [2528, 690], pos_in_scrolling_layout: [1, 2] } }], "OUT-1", W, H, false), true);
eq("one narrow column leaves the desktop visible", Cover.covered(spaces, [tile(1, 1, 846, 1388)], "OUT-1", W, H, false), false);
eq("a half-height window does not hide it", Cover.covered(spaces, [tile(1, 1, W, 700)], "OUT-1", W, H, false), false);
eq("an empty workspace is not covered", Cover.covered(spaces, [], "OUT-3", W, H, false), false);
eq("windows of another screen do not count", Cover.covered(spaces, [tile(1, 1, W, H)], "OUT-2", W, H, false), false);
eq("an inactive workspace does not count", Cover.covered(spaces, [tile(2, 1, W, H)], "OUT-1", W, H, false), false);
eq("the overview shows the desktop", Cover.covered(spaces, [tile(1, 1, W, H)], "OUT-1", W, H, true), false);
eq("a floating window never counts", Cover.covered(spaces, [tile(1, 1, W, H, true)], "OUT-1", W, H, false), false);
eq("unknown screen or no niri: never covered", [Cover.covered(spaces, [tile(1, 1, W, H)], "", W, H, false), Cover.covered({}, [], "OUT-1", W, H, false), Cover.covered(spaces, [tile(1, 1, W, H)], "OUT-1", 0, 0, false)], [false, false, false]);
eq("a window without layout yet does not count", Cover.covered(spaces, [{ workspace_id: 1 }], "OUT-1", W, H, false), false);

// Two volumes (D249, D255): this PC's level lives on a virtual sink in front of
// the device. Made-up address and names.
const MAC = "AA:BB:CC:DD:EE:01";
eq("virtual sink name", Route.virtualName(MAC), "orbit_pc_AA_BB_CC_DD_EE_01");
eq("lower-case address is accepted", Route.virtualName("aa:bb:cc:dd:ee:01"), "orbit_pc_AA_BB_CC_DD_EE_01");
eq("not an address: no name", [Route.virtualName("AA:BB"), Route.virtualName("x; rm -rf"), Route.virtualName(null)], ["", "", ""]);
eq("name back to address", Route.addressOfVirtual("orbit_pc_AA_BB_CC_DD_EE_01"), MAC);
eq("other sinks are not Orbit's", [Route.isVirtual("bluez_output.AA_BB_CC_DD_EE_01.1"), Route.addressOfVirtual("orbit_pc_nope")], [false, ""]);
eq("device sink recognised", [Route.isDeviceSink("bluez_output.AA_BB_CC_DD_EE_01.1"), Route.isDeviceSink("bluez_output.AA_BB_CC_DD_EE_01"), Route.isDeviceSink("alsa_output.usb-Card")], [true, true, false]);
eq("device sink address", Route.addressOfSink("bluez_output.aa_bb_cc_dd_ee_01.1"), MAC);
const pwNodes = [
    { name: "alsa_output.usb-Card", isSink: true, isStream: false },
    { name: "bluez_output.AA_BB_CC_DD_EE_01.1", isSink: true, isStream: false },
    { name: "orbit_pc_AA_BB_CC_DD_EE_01", isSink: true, isStream: false },
    { name: "bluez_output.AA_BB_CC_DD_EE_01.1", isSink: true, isStream: true }
];
eq("finds the device's sink, not a stream", Route.deviceSink(pwNodes, MAC), pwNodes[1]);
eq("finds the virtual sink", Route.virtualSink(pwNodes, MAC), pwNodes[2]);
eq("nothing for another device", [Route.deviceSink(pwNodes, "AA:BB:CC:DD:EE:02"), Route.virtualSink(pwNodes, "AA:BB:CC:DD:EE:02")], [null, null]);
eq("description keeps the name", Route.description("WH-1000XM6"), "WH-1000XM6 (Orbit)");
eq("description drops quotes and escapes", Route.description('My "Buds" \\ $(x)'), "My Buds (x) (Orbit)");
eq("empty name falls back", Route.description(""), "Bluetooth (Orbit)");
const filter = Route.filterArgs(MAC, "bluez_output.AA_BB_CC_DD_EE_01.1", "Buds \"Pro\"");
eq("smart filter: bash watches stdin, data only in $1 and $2", [filter.slice(0, 2), filter[3]], [["bash", "-c"], "orbit"]);
eq("smart filter: targets the device, nothing remembered", [/filter\.smart\.target=\{ node\.name = "bluez_output\.AA_BB_CC_DD_EE_01\.1" \}/.test(filter[4]), /node\.name=orbit_pc_AA_BB_CC_DD_EE_01 /.test(filter[4]), /state\.restore-props=false state\.restore-target=false$/.test(filter[5])], [true, true, true]);
eq("smart filter: quotes stripped from the name", /description="Buds Pro \(Orbit\)"/.test(filter[4]), true);
eq("bad master or address: no command", [Route.filterArgs(MAC, "x y", "B"), Route.filterArgs("nope", "bluez_output.AA_BB_CC_DD_EE_01.1", "B")], [null, null]);
eq("mute: one device mutes this PC, two mute the device", [Route.muteTarget(1), Route.muteTarget(2), Route.muteTarget(0)], ["pc", "device", "pc"]);
eq("ipc up/down in 5 % steps", [Route.ipcLevel("up", 0.5), Route.ipcLevel("down", 0.5), Route.ipcLevel("UP", 0.52)], [0.55, 0.45, 0.55]);
eq("ipc capped at the ends", [Route.ipcLevel("up", 1), Route.ipcLevel("down", 0), Route.ipcLevel("+20", 0.9), Route.ipcLevel("-20", 0.1)], [1, 0, 1, 0]);
eq("ipc absolute and relative", [Route.ipcLevel("40", 0.9), Route.ipcLevel("40%", 0), Route.ipcLevel("+5", 0.4), Route.ipcLevel("-10", 0.4)], [0.4, 0.4, 0.45, 0.3]);
eq("ipc rejects the rest", [Route.ipcLevel("150", 0), Route.ipcLevel("", 0), Route.ipcLevel("abc", 0), Route.ipcLevel("1000000", 0), Route.ipcLevel("4 0", 0), Route.ipcLevel(undefined, 0)], [-1, -1, -1, -1, -1, -1]);
const DEV = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_01";
const tree = "/org/bluez\n/org/bluez/hci0\n" + DEV + "\n" + DEV + "/sep1\n" + DEV + "/sep1/fd0\n/org/bluez/hci0/dev_AA_BB_CC_DD_EE_02/sep1/fd1\n";
eq("transport of the device", Route.transportPath(tree, DEV), DEV + "/sep1/fd0");
eq("no transport: no absolute volume", [Route.transportPath("/org/bluez\n" + DEV + "\n", DEV), Route.transportPath(tree, "/org/bluez/hci0/dev_x")], ["", ""]);
eq("transport volume", [Route.transportVolume('{"type":"q","data":65}'), Route.transportVolume("oops"), Route.transportVolume('{"type":"q","data":300}')], [65, -1, -1]);
eq("level notes say why", [Guide.levelNote("no-device").length > 0, Guide.levelNote("bad-level").indexOf("0 to 100") > 0], [true, true]);

// Polar vectorscope (D250, D254): angles clockwise from the right, top = 270
eq("outer arc lights from the left", [Polar.arc("outer", 0.5), Polar.arc("inner", 2)], [{ start: 180, sweep: 90 }, { start: 180, sweep: 180 }]);
eq("split: each quarter from its bottom corner", [Polar.arc("d1", 1), Polar.arc("d2", 0.5)], [{ start: 180, sweep: 90 }, { start: 360, sweep: -45 }]);
eq("moons", [Polar.end("outer", 0), Polar.end("outer", 1), Polar.end("d2", 1)], [180, 360, 270]);
const pTop = Polar.point(100, 100, 50, 270);
eq("top point", [Math.round(pTop.x), Math.round(pTop.y)], [100, 50]);
eq("drag value", [Polar.valueAt("outer", -10, 0), Polar.valueAt("outer", 0, -10), Polar.valueAt("outer", 10, 0), Polar.valueAt("inner", 7, -7)], [0, 0.5, 1, 0.75]);
eq("below the baseline snaps to the nearer end", [Polar.valueAt("outer", 10, 5), Polar.valueAt("outer", -10, 5)], [1, 0]);
eq("split drag", [Polar.valueAt("d1", 0, -10), Polar.valueAt("d1", -10, -10), Polar.valueAt("d2", 10, -10), Polar.valueAt("d2", -10, -10)], [1, 0.5, 0.5, 1]);
eq("zones", [Polar.zone(0, -100, 100, 40, 10, false), Polar.zone(0, -42, 100, 40, 10, false), Polar.zone(0, -70, 100, 40, 10, false), Polar.zone(0, 30, 100, 40, 10, false)], ["outer", "inner", "", ""]);
eq("split zones", [Polar.zone(-60, -80, 100, 40, 10, true), Polar.zone(60, -80, 100, 40, 10, true)], ["d1", "d2"]);
const fr = Polar.parseFrame("9;35;30;45;100;80;3;0;0;3;80;100;45;30;35;9;", 8);
eq("cava frame: left reversed, low notes first", [fr.l, fr.r], [[0, 0.03, 0.8, 1, 0.45, 0.3, 0.35, 0.09], [0, 0.03, 0.8, 1, 0.45, 0.3, 0.35, 0.09]]);
eq("bad frames", [Polar.parseFrame("1;2;3;", 8), Polar.parseFrame("a;b;c;d;e;f;g;h;i;j;k;l;m;n;o;p;", 8), Polar.parseFrame("", 8), Polar.parseFrame("0;0;0;0;0;0;0;0;0;0;0;0;0;0;0;101;", 8)], [null, null, null, null]);
eq("loudness", [Polar.loudness(fr), Polar.loudness(null)], [1, 0]);
const mono = { l: [0.5], r: [0.5] }, hardL = { l: [0.8], r: [0] }, hardR = { l: [0], r: [0.8] };
eq("mono sits on the vertical", Polar.spawn(mono, 0, 100, 0.5, 1, 0).deg, 270);
eq("hard left / right go to the sides", [Polar.spawn(hardL, 0, 100, 0.5, 1, 0).deg, Polar.spawn(hardR, 0, 100, 0.5, 1, 0).deg], [183, 357]);
eq("louder goes further", Polar.spawn({ l: [1], r: [1] }, 0, 100, 0.5, 1, 0).dist > Polar.spawn({ l: [0.2], r: [0.2] }, 0, 100, 0.5, 1, 0).dist, true);
eq("silence spawns nothing", [Polar.spawn({ l: [0], r: [0.01] }, 0, 100, 0.5, 0.5, 0.5), Polar.spawn(mono, 4, 100, 0.5, 0.5, 0.5)], [null, null]);
eq("cava config", Polar.cavaConfig("orbit_pc_AA.monitor", 60, 8).split("\n").filter(l => /source|bars|framerate|channels/.test(l)), ["framerate = 60", "bars = 16", "source = orbit_pc_AA.monitor", "channels = stereo"]);
eq("cava config refuses odd names", [Polar.cavaConfig("x\nmethod = fifo", 60, 8), Polar.cavaConfig("", 60, 8)], [null, null]);
eq("foot icons", [Route.iconFor("headphonesPremium"), Route.iconFor("earbudsStem"), Route.iconFor("soundbar"), Route.iconFor("bluetooth")], ["headphones", "earbuds", "speaker", "speaker"]);
eq("pop-up sizes, medium by default", [Route.popupSize("compact"), Route.popupSize("x"), Route.popupSize("large").h], [{ w: 280, h: 150 }, { w: 360, h: 200 }, 260]);

print(failures ? failures + "/" + count + " failed" : count + " tests passed");
imports.system.exit(failures ? 1 : 0);
