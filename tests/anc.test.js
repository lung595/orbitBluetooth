// Pure-logic tests for every components/<feature>/*.js module.
// Run from the plugin root: gjs tests/anc.test.js
const GLib = imports.gi.GLib;

const root = GLib.path_get_dirname(GLib.path_get_dirname(GLib.canonicalize_filename(imports.system.programPath ?? "tests/anc.test.js", GLib.get_current_dir())));

// The modules live in feature folders: components/<feature>/<Name>.js
const features = ["card", "common", "device", "noise", "pairing", "scene", "volume"];
function pathOf(file) {
    const folder = features.find(f => GLib.file_test(root + "/components/" + f + "/" + file, GLib.FileTest.EXISTS));
    return root + "/components/" + folder + "/" + file;
}

// QML ".pragma library" files are plain JS once the pragma is removed
function load(file, names) {
    const [, bytes] = GLib.file_get_contents(pathOf(file));
    const src = new TextDecoder().decode(bytes).replace(".pragma library", "");
    return new Function(src + "; return { " + names.join(", ") + " };")();
}

const Anc = load("Anc.js", ["family", "nextMode", "ordered"]);
const Charge = load("Charge.js", ["analyze", "formatShort", "timeText", "levelText", "statItems", "footnote"]);
const Endurance = load("Endurance.js", ["ratedHours"]);
const Palette = load("Palette.js", ["contrast", "ensureContrast", "onColor", "lift", "isGrey", "toHsl", "apart"]);
const Offer = load("Offer.js", ["scanBlocker", "isCandidate", "offerable", "headline", "features", "errorText"]);
const Pictures = load("Pictures.js", ["queryFor", "creditText"]);
const Catalog = load("DeviceCatalog.js", ["deviceName", "modelName", "resolve"]);
const Guide = load("Guide.js", ["url", "connectNote", "blockedNote", "noVolumeNote", "stuckNote", "levelNote"]);
const Audiophile = load("Audiophile.js", ["INFOS", "connectionOf", "factsOf", "parse", "kilohertz", "chainOf", "textOf", "line", "rows"]);
const Volume = load("Volume.js", ["clamp", "step", "validSink"]);
const Guard = load("Guard.js", ["offerFamily", "hasInput", "refused", "validPath", "parseUuids"]);
const Cover = load("Cover.js", ["covered"]);
const Orbit = load("Orbit.js", ["pick", "plan", "changes"]);
const Physics = load("Physics.js", ["spring", "norm", "ringSlot", "beltSlot", "beltRadius", "dragTarget", "dragArm", "separate", "moving"]);
const Polar = load("Polar.js", ["LEFT", "TOP", "RIGHT", "arc", "end", "point", "angleOf", "valueAt", "zone", "parseFrame", "loudness", "spawn", "cavaConfig", "styleOf", "emptyLevels", "levelAt", "reach", "rayAngles", "follow", "heardLevel", "scaleFor", "ease"]);
const Steps = load("Steps.js", ["SPEEDS", "speedOf", "stepAt", "next", "apply", "fixedStep"]);
const Keys = load("Keys.js", ["KEYS", "action", "setArgs", "backArgs", "dmsAction", "isOrbit", "classify", "succeeded", "note"]);
const Route = load("Route.js", ["addressKey", "virtualName", "isVirtual", "addressOfVirtual", "isDeviceSink", "addressOfSink", "deviceSink", "virtualSink", "description", "filterArgs", "muteTarget", "ipcLevel", "transportPath", "transportVolume", "iconFor", "popupSize", "popupLayout", "shownLevels"]);

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

// The card's lines and tiles: "≈" only on an estimate, nothing made up
const drain = { source: "rated", minutesLeft: 90, ratePerHour: -12, health: 0 };
const fill = { source: "system", minutesToFull: 30, fullAt: now + 30 * 60000, watts: 0, ratePerHour: 40, gained: 8, since: now - 20 * 60000, health: 92 };
eq("time left, estimated", Charge.timeText(drain, false), "≈ 1 h 30 left");
eq("time to full, reported", Charge.timeText(fill, true), "30 min to full");
eq("charging, no speed yet", Charge.timeText({ source: "estimated" }, true), "Measuring…");
eq("draining, no figure", Charge.timeText({ source: "estimated" }, false), "");
eq("level line, draining", Charge.levelText(60, drain, false), "60%  •  ≈ 1 h 30 left");
eq("level line, charging", Charge.levelText(80, fill, true), "80%  •  Full in 30 min");
eq("level line, unknown", Charge.levelText(40, null, false), "40%");
eq("tiles, draining", Charge.statItems(drain, false, now).map(t => t.label).join(","), "EMPTY AT,DRAIN");
const tiles = Charge.statItems(fill, true, now);
eq("tiles, charging", tiles.map(t => t.label).join(","), "READY AT,SPEED,+8% IN,HEALTH");
eq("tiles, charging values", tiles.slice(1).map(t => t.value).join(","), "+40 %/h,20 min,92%");
eq("ready at, reported: no ≈", tiles[0].value.startsWith("≈"), false);
eq("tiles, full", Charge.statItems({ source: "system", state: "full", health: 0 }, false, now).length, 0);
eq("footnote, reported", Charge.footnote(fill, true), "Reported by the device");
eq("footnote, rated", Charge.footnote(drain, false), "From the rated battery life · refines as it drains");


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

// Two accents never pass for each other (D270): a pink and a salmon (the
// generated theme that showed it) become a pink and a mint; far apart or
// grey, the second accent stays as it is
const hue = c => Math.round(Palette.toHsl(c).h * 360);
const mint = Palette.apart(hex("#FFB3AE"), hex("#FCABF6"));
eq("near twins: opposite hue", Math.abs(hue(mint) - (hue(hex("#FCABF6")) + 180) % 360) <= 1, true);
eq("near twins: own lightness", Math.round(Palette.toHsl(mint).l * 100), Math.round(Palette.toHsl(hex("#FFB3AE")).l * 100));
eq("far apart: unchanged", hue(Palette.apart(hex("#2F6A5E"), hex("#FCABF6"))), hue(hex("#2F6A5E")));
eq("grey: unchanged", hue(Palette.apart(hex("#BDBDBD"), hex("#FCABF6"))), hue(hex("#BDBDBD")));

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
["noise-control", "pairing-safety", "if-it-does-not-connect", "if-it-does-not-disconnect", "bluetooth-is-off", "the-two-volumes", "new-headphones-pop-up"].forEach(a => eq("guide has #" + a, anchors.indexOf(a) >= 0, true));
eq("guide url", Guide.url("noise-control"), "https://github.com/lung595/orbitBluetooth/blob/main/docs/GUIDE.md#noise-control");
eq("a nameless device", Guide.connectNote("pair", "").title, "Could not pair this device");

// --- Volume tick (Volume.js) ------------------------------------------------------
eq("same step: no tick", Volume.step(0.61) === Volume.step(0.62), true);
eq("next step: tick", Volume.step(0.62) === Volume.step(0.68), false);
eq("levels are clamped", [Volume.clamp(-1), Volume.clamp(2), Volume.clamp("x")], [0, 1, 0]);
eq("node name ok for pw-play", Volume.validSink("bluez_output.02_00_00_00_10_06.1"), true);
eq("no shell characters", Volume.validSink("x; rm -rf ~"), false);
eq("no option smuggling", Volume.validSink("--target=x y"), false);

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
eq("empty levels are a fresh frame each time", [Polar.emptyLevels(), Polar.emptyLevels() !== Polar.emptyLevels()], [{ l: [], r: [] }, true]);
eq("visualizer style: unknown falls back to points", [Polar.styleOf("rays"), Polar.styleOf("waves"), Polar.styleOf("none"), Polar.styleOf("x")], ["rays", "waves", "none", "points"]);
const sp = { l: [1, 0.5, 0], r: [0.2, 0.4, 0.6] };
eq("level at the top is the left bass, at the sides the highs", [Polar.levelAt(sp, 269.999) > 0.99, Polar.levelAt(sp, 180), Polar.levelAt(sp, 360)], [true, 0, 0.6]);
eq("level interpolates between bands", Math.round(Polar.levelAt(sp, 225) * 100) / 100, 0.5);
eq("no frame: no level", Polar.levelAt(null, 200), 0);
eq("silence keeps a faint ring, full reaches the edge", [Polar.reach(0, 100), Polar.reach(1, 100)], [16, 100]);
const ra = Polar.rayAngles(4);
eq("rays: two per band, inside the half circle, symmetric", [ra.length, ra.every(d => d > 180 && d < 360), ra[0] + ra[1]], [8, true, 540]);
eq("meter: up fast, down slowly", [Polar.follow(0, 1, 0.05) > 0.55, Polar.follow(1, 0, 0.05) > 0.7], [true, true]);
eq("meter: the same glide at 30 and 60 Hz", Math.abs(Polar.follow(Polar.follow(0, 1, 1 / 60), 1, 1 / 60) - Polar.follow(0, 1, 1 / 30)) < 1e-9, true);
eq("level curve stays inside 0..1 on a spike", [0, 0.25, 0.5, 0.75, 1].every(f => { const v = Polar.levelAt({ "l": [0, 1, 0, 1], "r": [0, 0, 0, 0] }, 270 - f * 90); return v >= 0 && v <= 1; }), true);
eq("heard: device level times this PC's, muted anywhere is silence", [Polar.heardLevel(0.5, 0.8, false, false), Polar.heardLevel(0.5, 0.8, true, false), Polar.heardLevel(0.5, 0.8, false, true)], [0.4, 0, 0]);
eq("heard: no level of its own, this PC's alone", [Polar.heardLevel(-1, 0.8, true, false), Polar.heardLevel(-1, 0.8, false, true)], [0.8, 0]);
eq("picture grows with the volume", [Polar.scaleFor(0), Polar.scaleFor(1), Polar.scaleFor(0.25) < Polar.scaleFor(0.5)], [0.22, 1, true]);
eq("ease reaches its target", Math.abs(Polar.ease(0, 1, 2, 10) - 1) < 1e-6, true);
eq("cava config", Polar.cavaConfig("orbit_pc_AA.monitor", 60, 8).split("\n").filter(l => /source|bars|framerate|channels/.test(l)), ["framerate = 60", "bars = 16", "source = orbit_pc_AA.monitor", "channels = stereo"]);
eq("cava config refuses odd names", [Polar.cavaConfig("x\nmethod = fifo", 60, 8), Polar.cavaConfig("", 60, 8)], [null, null]);
eq("foot icons", [Route.iconFor("headphonesPremium"), Route.iconFor("earbudsStem"), Route.iconFor("soundbar"), Route.iconFor("bluetooth")], ["headphones", "earbuds", "speaker", "speaker"]);
eq("pop-up sizes, medium by default", [Route.popupSize("compact"), Route.popupSize("x"), Route.popupSize("large").h], [{ w: 300, h: 172 }, { w: 420, h: 236 }, 300]);

// The volume pop-up (D258): where it stands, which levels it shows
eq("pop-up lies flat in place of DMS's OSD", Route.popupLayout("replace", false, false, "medium"), { w: 420, h: 236, upright: false, rotation: 0 });
eq("upright on the right edge, flat side against it", Route.popupLayout("edge", false, false, "large"), { w: 300, h: 540, upright: true, rotation: -90 });
// Smart volume steps (D264), rhythms taken from a real recording
{
    // `n` notches `gap` ms apart, after a long pause; the steps taken
    const run = (gap, n, speed, level, state) => {
        let st = state || null, steps = [];
        for (let k = 0; k < n; k++) {
            const r = Steps.next(st, 100000 + k * gap, 1, speed || "balanced", level === undefined ? 0.5 : level);
            st = r.state;
            steps.push(r.step);
        }
        return steps;
    };
    const sum = a => a.reduce((x, y) => x + y, 0);
    eq("a notch on its own is 1 %", Steps.next(null, 1000, 1, "balanced", 0.5).step, 1);
    eq("slow notches stay at 1 %", run(600, 6), [1, 1, 1, 1, 1, 1]);
    eq("a quick run builds up, never jumps", run(20, 8), [1, 1, 2, 3, 3, 4, 4, 4]);
    eq("two or three quick notches stay fine", sum(run(20, 3)), 4);
    eq("the slower the run, the less it moves", [20, 60, 120, 200, 300].map(g => sum(run(g, 8))).every((v, k, a) => k === 0 || v <= a[k - 1]), true);
    eq("the curve is smooth from 1 % to the ceiling", Steps.stepAt(300, "balanced") === 1 && Steps.stepAt(25, "balanced") === 4 && Steps.stepAt(160, "balanced") > 1.5 && Steps.stepAt(160, "balanced") < 2.5, true);
    eq("turning back starts over", Steps.next({ "last": 0, "dir": 1, "gap": 20, "run": 8 }, 20, -1, "balanced", 0.5).step, 1);
    eq("turning back soon is hunting: one step below the ceiling", (() => {
        let st = { "last": 0, "dir": 1, "gap": 20, "run": 8 };
        const steps = [];
        for (let k = 1; k <= 10; k++) {
            const r = Steps.next(st, 200 + k * 20, -1, "balanced", 0.5);
            st = r.state;
            steps.push(r.step);
        }
        return Math.max(...steps);
    })(), 3);
    eq("a pause ends the hunt", Math.max(...run(20, 10, "balanced", 0.5, { "last": 0, "dir": -1, "gap": 20, "run": 4, "hunting": true })), 4);
    eq("quiet levels stay fine", run(20, 10, "balanced", 0.05), [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]);
    eq("going down into the quiet part slows", Steps.next({ "last": 0, "dir": -1, "gap": 20, "run": 8 }, 20, -1, "balanced", 0.12).step, 1);
    eq("fast goes further, gentle less", [Math.max(...run(20, 12, "fast")), Math.max(...run(20, 12, "gentle"))], [6, 3]);
eq("an unknown speed is balanced", Steps.speedOf("warp"), "balanced");
    eq("apply lands on whole percents, inside 0..1", [Steps.apply(0.394, 1, 1), Steps.apply(0.99, 1, 8), Steps.apply(0.02, -1, 5)], [0.4, 1, 0]);
    eq("fixed step is 1..10", [Steps.fixedStep("3"), Steps.fixedStep("99"), Steps.fixedStep("x")], [3, 10, 5]);
}
eq("follows DMS's OSD on a side", [Route.popupLayout("replace", true, true, "compact").rotation, Route.popupLayout("replace", true, false, "x").rotation, Route.popupLayout("bar", true, true, "x").upright], [90, -90, false]);
const nd = { n: "dev" }, np = { n: "pc" };
eq("two levels", Route.shownLevels(nd, np), { device: nd, pc: np, ownIcon: false });
eq("one level, the device's own", Route.shownLevels(nd, null), { device: null, pc: nd, ownIcon: true });
eq("one level, this PC's (not Bluetooth, or no own volume)", [Route.shownLevels(null, np), Route.shownLevels(null, null)], [{ device: null, pc: np, ownIcon: false }, { device: null, pc: null, ownIcon: false }]);

// Volume keys bound to Orbit in one click (D265), from made-up listings
{
    const listing = (up, down) => JSON.stringify({ "binds": { "Audio": [
        { "key": "XF86AudioRaiseVolume", "action": up, "source": "dms-default" },
        { "key": "XF86AudioLowerVolume", "action": down, "source": "dms-default" },
        { "key": "Mod+T", "action": "spawn foot" }] } });
    const dmsUp = "spawn dms ipc call audio increment 3", dmsDown = "spawn dms ipc call audio decrement 3";
    eq("DMS's default keys can be offered", Keys.classify(listing(dmsUp, dmsDown)), { state: "dms", step: 3, mine: [], back: {} });
    eq("DMS's default keys can be offered", Keys.classify(listing(dmsUp, dmsDown)).back, {});
    eq("both keys on Orbit", Keys.classify(listing(Keys.action("up", 3), Keys.action("down", 3))), { state: "orbit", step: 3, mine: ["up", "down"], back: { up: 3, down: 3 } });
    eq("one key on Orbit is custom, but still given back", Keys.classify(listing(Keys.action("up", 3), "spawn my-script")), { state: "custom", step: 3, mine: ["up"], back: { up: 3 } });
    // How `dms keybinds show` prints Orbit's action: arguments unquoted
    eq("the DMS step comes back from Orbit's action", Keys.classify(listing('spawn sh -c "case ... ipc call orbitBluetooth volume ... esac orbit up increment 5"', Keys.action("down", 7))).back, { up: 5, down: 7 });
    eq("the user's own shortcut is left alone", Keys.classify(listing("spawn pamixer -i 5", dmsDown)).state, "custom");
    eq("swapped DMS verbs are not DMS's default", Keys.classify(listing(dmsDown, dmsUp)).state, "custom");
    eq("a missing key is custom", Keys.classify(JSON.stringify({ "binds": {} })).state, "custom");
    eq("DMS's own step is kept for the fallback", Keys.classify(listing("spawn dms ipc call audio increment 5", "spawn dms ipc call audio decrement 5")).step, 5);
    eq("an unreadable listing is unknown", [Keys.classify("").state, Keys.classify("oops").state, Keys.classify("null").state, Keys.classify('{"binds":null}').state], ["unknown", "unknown", "unknown", "unknown"]);
    eq("the action falls back to DMS's step, data as parameters only", Keys.action("down", 3),
        'spawn "sh" "-c" "case \\"$(dms ipc call orbitBluetooth volume \\"$1\\")\\" in \\"\\"|Target*|Function*) exec dms ipc call audio \\"$2\\" \\"$3\\";; esac" "orbit" "down" "decrement" "3"');
    eq("the fallback step stays 1..20", [Keys.action("up", 99).slice(-4), Keys.action("up", "x").slice(-3)], ['"20"', '"3"']);
    eq("set only the volume keys", [Keys.setArgs("up", 3).slice(0, 5), Keys.setArgs("up", 3).slice(-2)],
        [["dms", "keybinds", "set", "niri", "XF86AudioRaiseVolume"], ["--allow-when-locked", "--json"]]);
    // Not `reset`: DMS's binds.kdl is the default, a reset unbinds the key
    eq("undo writes DMS's own action back", Keys.backArgs("down", 5), ["dms", "keybinds", "set", "niri", "XF86AudioLowerVolume", "spawn dms ipc call audio decrement 5", "--allow-when-locked", "--json"]);
    eq("DMS's action, step kept in 1..20", [Keys.dmsAction("up", 3), Keys.dmsAction("up", 0)], ["spawn dms ipc call audio increment 3", "spawn dms ipc call audio increment 3"]);
    eq("only a success answer counts", [Keys.succeeded('{"success":true}'), Keys.succeeded('{"success":false}'), Keys.succeeded(""), Keys.succeeded("null")], [true, false, false, false]);
    eq("notes", [Keys.note("offer").action, Keys.note("done").action, Keys.note("nope")], ["Enable", "Undo", null]);
}

// Which devices get a planet, from made-up devices (no RSSI, as Quickshell)
{
    const dev = (address, name, more) => Object.assign({ address: address, name: name }, more);
    const unnamed = d => !d.name;
    const opts = (more) => Object.assign({ isHidden: a => a === "hid", isUnnamed: unnamed, showUnnamed: false, maxDevices: 2 }, more);
    const addresses = list => list.map(d => d.address);
    const all = [
        dev("far", "Speaker", { signalStrength: 20 }),
        dev("near", "Mouse", { signalStrength: 80 }),
        dev("anon", ""),
        dev("pair", "Keyboard", { paired: true }),
        dev("bond", "Pad", { bonded: true }),
        dev("on", "Headset", { connected: true, paired: true }),
        dev("hid", "Hidden", { connected: true }),
        dev("block", "Blocked", { blocked: true }),
        dev("gone", "Gone", { signalStrength: 0 }),
        null
    ];
    eq("connected first, then paired, up to maxDevices in all", addresses(Orbit.pick(all, opts())), ["on", "pair"]);
    eq("named before unnamed, then the strongest signal", addresses(Orbit.pick(all, opts({ maxDevices: 9, showUnnamed: true }))), ["on", "pair", "bond", "near", "far", "anon"]);
    eq("unnamed devices stay out unless asked", Orbit.pick(all, opts({ maxDevices: 9 })).some(d => d.address === "anon"), false);
    eq("an unnamed connected device always shows", addresses(Orbit.pick([dev("x", "", { connected: true })], opts())), ["x"]);
    eq("connected devices never count against the cap", addresses(Orbit.pick(all, opts({ maxDevices: 0 }))), ["on"]);

    const a = { address: "a" }, b = { address: "b" }, c = { address: "c" };
    const entries = [{ address: "a", leaving: false }, { address: "b", leaving: false }, { address: "c", leaving: true }];
    const step = Orbit.plan(entries, { a: a, c: c, d: { address: "d" } }, { a: a, b: b, c: c });
    eq("a device that went away starts leaving, one back stops", step.marks, [[1, true], [2, false]]);
    eq("a new device gets a body", step.added, ["d"]);
    eq("a leaving device stays resolvable", Object.keys(step.devices), ["a", "c", "d", "b"]);
    eq("nothing changes, nothing to do", Orbit.plan([{ address: "a", leaving: false }], { a: a }, { a: a }), { marks: [], added: [], devices: { a: a } });
    eq("an unknown leaving entry is not resolved", Object.keys(Orbit.plan([{ address: "z", leaving: true }], {}, {}).devices), []);
    eq("changes: what to start and stop, in order", Orbit.changes(["a", "b", "c"], ["d", "c", "a", "e"]), { added: ["d", "e"], removed: ["b"] });
    eq("changes: same set in another order, nothing", Orbit.changes(["a", "b"], ["b", "a"]), { added: [], removed: [] });
}

// Orbit physics: a 200x100 scene, ring at 0.5, black hole far away
{
    const g = { cx: 100, cy: 50, rx: 80, ry: 40, ringCy: 50, ringRy: 20, innerNorm: 0.5, snapNorm: 0.7, detachNorm: 0.8, outerMinNorm: 0.8,
        bodySize: 20, coreSize: 20, holeX: 1000, holeY: 1000, holeHorizon: 5 };
    const r = v => Math.round(v * 100) / 100;
    eq("norm: center 0, belt edge 1", [Physics.norm(g, 100, 50), Physics.norm(g, 180, 50), Physics.norm(g, 100, 90)], [0, 1, 1]);
    eq("first ring slot at the phase angle", (s => [r(s.x), r(s.y), r(s.depth)])(Physics.ringSlot(g, 0, 4, 0)), [140, 50, 0]);
    eq("ring slots split the turn evenly", (s => [r(s.x), r(s.y), r(s.depth)])(Physics.ringSlot(g, 1, 4, 0)), [100, 70, 1]);
    eq("an empty ring does not divide by zero", r(Physics.ringSlot(g, 0, 0, 0).x), 140);
    eq("belt radius: stronger signal, closer (clamped)", [Physics.beltRadius(g, 0), Physics.beltRadius(g, 1), Physics.beltRadius(g, 5)].map(r), [1, 0.8, 0.8]);
    eq("belt slot without float: on the ellipse", (s => [r(s.x), r(s.y)])(Physics.beltSlot(g, 0, 2, 0, 0.5, 1, 0, 0)), [100, 90]);
    eq("float stays within its amplitude", Math.abs(Physics.beltSlot(g, 0, 2, 0, 0.5, 1, 3.7, 4).x - 100) <= 4, true);

    const b = { px: 0, py: 0, vx: 0, vy: 0 };
    for (let i = 0; i < 300; i++)
        Physics.spring(b, 10, -5, 70, 0.58, 1 / 60);
    eq("the spring settles on its target", [r(b.px), r(b.py)], [10, -5]);
    eq("a settled body is not moving", Physics.moving(b, 10, -5), false);
    const c = { px: 0, py: 0, vx: 0, vy: 0 };
    let over = 0;
    for (let i = 0; i < 300; i++) {
        Physics.spring(c, 10, 0, 70, 1, 1 / 60);
        over = Math.max(over, c.px);
    }
    eq("critical damping (Reduce motion) never overshoots", over <= 10.001, true);

    eq("a free drag follows the pointer", Physics.dragTarget(g, {}, 30, 20), { x: 30, y: 20, k: 700, zeta: 0.85 });
    const magnet = Physics.dragTarget(g, { armed: true }, 145, 50);
    eq("the ring's magnet pulls a new device in", [magnet.x < 145, magnet.k, magnet.zeta], [true, 380, 0.62]);
    // Pulled 10 px off its ring (norm 0.625): held back by a third
    const held = Physics.dragTarget(g, { holding: true }, 150, 50);
    eq("a connected device resists leaving its ring", [r(held.x), r(held.y)], [146.75, 50]);
    eq("past the tear point it follows freely", r(Physics.dragTarget(g, { holding: true }, 180, 50).x), 180);
    eq("armed to disconnect, the ring barely holds", r(Physics.dragTarget(g, { holding: true, armed: true }, 150, 50).x), 149.2);
    const hidden = Physics.dragTarget(Object.assign({}, g, { holeX: 0, holeY: 0 }), { hideArmed: true }, 100, 100);
    eq("aimed at the black hole, it is pulled in", [r(hidden.x), r(hidden.y), hidden.k], [45, 45, 420]);

    // Off the exact center, so the core's push has a direction
    const me = { px: 105, py: 50, inSlot: false }, other = { px: 110, py: 50 };
    const t = { x: 105, y: 50 };
    Physics.separate(g, me, t, [me, other], false);
    eq("neighbours push apart, the core pushes out", [r(t.x), r(t.y)], [79, 50]);
    const alone = { x: 105, y: 50 };
    Physics.separate(g, me, alone, [me], false);
    eq("too close to the core, it is put on its edge", [r(alone.x), r(alone.y)], [121, 50]);
    const card = { x: 105, y: 50 };
    Physics.separate(g, me, card, [me], true);
    eq("with a card open, the center is allowed", card, { x: 105, y: 50 });
    const slotted = { px: 105, py: 50, inSlot: true }, slot = { x: 105, y: 50 };
    Physics.separate(g, slotted, slot, [slotted], false);
    eq("a body in its ring slot keeps it", slot, { x: 105, y: 50 });
    const nearHole = { x: 140, y: 50 };
    Physics.separate(Object.assign({}, g, { holeX: 150, holeY: 50 }), { px: 0, py: 0 }, nearHole, [], false);
    eq("nothing settles in the black hole's reach", [r(nearHole.x), r(nearHole.y)], [127, 50]);
    const far = { px: 150, py: 50 }, dragged = { x: 150, y: 50 }, still = { x: 150, y: 50 };
    Physics.separate(g, far, dragged, [far, { px: 170, py: 50, dragging: true }], false);
    Physics.separate(g, far, still, [far, { px: 170, py: 50 }], false);
    eq("a dragged body clears a wider path", [r(dragged.x), r(still.x)], [134.29, 149.43]);
    eq("drag: a free body arms inside the magnet", [Physics.dragArm(g, false, 150, 50).armed, Physics.dragArm(g, false, 160, 50).armed], [true, false]);
    eq("drag: a connected body arms past the tear point", [Physics.dragArm(g, true, 160, 50).armed, Physics.dragArm(g, true, 170, 50).armed], [false, true]);
    eq("drag: far from the hole, no hide and no glow", Physics.dragArm(g, false, 150, 50), { hide: false, armed: true, feed: 0 });
    const hole = Object.assign({}, g, { holeX: 150, holeY: 50 });
    eq("drag: over the hole it hides, never connects", Physics.dragArm(hole, true, 160, 50), { hide: true, armed: false, feed: 1 });
    eq("drag: the glow fades with distance", r(Physics.dragArm(hole, false, 150, 90).feed), 0.13);
    eq("drag: the hide reach is at least 3/4 of a body", [Physics.dragArm(hole, false, 164, 50).hide, Physics.dragArm(hole, false, 166, 50).hide], [true, false]);
}

// --- Audio facts (Audiophile.js) --------------------------------------------------
{
    const sinks = JSON.stringify([
        { name: "alsa_output.usb-X.HiFi__Line1__sink", sample_specification: "s32le 2ch 192000Hz", properties: { "device.bus": "usb", "device.api": "alsa", "api.alsa.path": "hw:Gen" } },
        { name: "alsa_output.pci-0000_01_00.1.hdmi-stereo", sample_specification: "s32le 2ch 48000Hz", properties: { "device.bus": "pci", "device.api": "alsa", "api.alsa.path": "hdmi:0" } },
        { name: "alsa_output.pci-0000_0d_00.6.iec958-stereo", sample_specification: "s16le 2ch 44100Hz", properties: { "device.bus": "pci", "device.api": "alsa", "api.alsa.path": "iec958:1" } },
        { name: "alsa_output.pci-0000_0d_00.6.analog-stereo", sample_specification: "s24le 2ch 96000Hz", properties: { "device.bus": "pci", "device.api": "alsa", "api.alsa.path": "hw:Generic" } },
        { name: "bluez_output.AA_BB_CC_DD_EE_FF.1", sample_specification: "float32le 2ch 96000Hz", properties: { "api.bluez5.codec": "ldac", "device.api": "bluez5" } },
        { name: "bluez_output.11_22_33_44_55_66.1", sample_specification: "s16le 2ch 48000Hz", properties: { "api.bluez5.codec": "sbc_xq" } }
    ]);
    const facts = Audiophile.parse(sinks);
    eq("how each output is connected", Object.values(facts).map(f => f.connection), ["USB", "HDMI", "S/PDIF", "Analog", "Bluetooth", "Bluetooth"]);
    eq("USB card: rate and depth from the sink", [facts["alsa_output.usb-X.HiFi__Line1__sink"].rate, facts["alsa_output.usb-X.HiFi__Line1__sink"].bits], [192000, 32]);
    eq("float sink format still reads its number", Audiophile.parse(sinks)["bluez_output.AA_BB_CC_DD_EE_FF.1"].rate, 96000);
    eq("Bluetooth bits come from the codec, not the sink", [facts["bluez_output.AA_BB_CC_DD_EE_FF.1"].bits, facts["bluez_output.11_22_33_44_55_66.1"].bits], [24, 16]);
    eq("codec names are written as people write them", [facts["bluez_output.AA_BB_CC_DD_EE_FF.1"].codec, facts["bluez_output.11_22_33_44_55_66.1"].codec], ["LDAC", "SBC-XQ"]);
    eq("a wired output has no codec", facts["alsa_output.usb-X.HiFi__Line1__sink"].codec, "");
    eq("not JSON gives nothing", [Audiophile.parse("oops"), Audiophile.parse("{}"), Audiophile.parse("")], [{}, {}, {}]);
    eq("an unknown output is not named", Audiophile.connectionOf("x", {}), "");
    eq("kilohertz are short", [Audiophile.kilohertz(48000), Audiophile.kilohertz(44100), Audiophile.kilohertz(0)], ["48 kHz", "44.1 kHz", ""]);

    const bt = facts["bluez_output.AA_BB_CC_DD_EE_FF.1"];
    const card = { connection: true, codec: true, rate: true, bits: true };
    eq("the card's line", Audiophile.line(bt, card, null), "Bluetooth · LDAC · 96 kHz · 24 bit");
    eq("a fact left off the line", Audiophile.line(bt, { rate: true }, null), "96 kHz");
    eq("nothing chosen, no line", Audiophile.line(bt, {}, null), "");
    eq("a wired output skips the missing codec", Audiophile.line(facts["alsa_output.usb-X.HiFi__Line1__sink"], card, null), "USB · 192 kHz · 32 bit");
    eq("resampling is signalled", Audiophile.chainOf({ rate: 48000 }, { rate: 96000 }), "Resampled 48 kHz to 96 kHz");
    eq("same rate, nothing to signal", [Audiophile.chainOf({ rate: 48000 }, { rate: 48000 }), Audiophile.chainOf(null, { rate: 48000 })], ["", ""]);
    eq("detail rows keep the order and the labels", Audiophile.rows(bt, { codec: true, channels: true, chain: true }, { rate: 48000 }), [
        { label: "Codec", text: "LDAC" }, { label: "Channels", text: "Stereo" }, { label: "PC to device", text: "Resampled 48 kHz to 96 kHz" }]);
    eq("no facts, no line", [Audiophile.line(null, card, null), Audiophile.rows(null, card, null)], ["", []]);
}

print(failures ? failures + "/" + count + " failed" : count + " tests passed");
imports.system.exit(failures ? 1 : 0);
