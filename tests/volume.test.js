// Volumes: the tick, the two levels' routing, the vectorscope, smart steps, volume keys.
// Run from the plugin root: gjs tests/volume.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Guide = load("Guide.js", ["url", "connectNote", "blockedNote", "noVolumeNote", "stuckNote", "levelNote"]);
const Volume = load("Volume.js", ["clamp", "step", "validSink"]);
const Polar = load("Polar.js", ["LEFT", "TOP", "RIGHT", "arc", "end", "point", "angleOf", "valueAt", "zone", "wheelPart", "parseFrame", "loudness", "spawn", "cavaConfig", "styleOf", "emptyLevels", "levelAt", "reach", "rayAngles", "follow", "heardLevel", "scaleFor", "ease"]);
const Steps = load("Steps.js", ["SPEEDS", "speedOf", "stepAt", "next", "apply", "fixedStep"]);
const Keys = load("Keys.js", ["KEYS", "action", "setArgs", "backArgs", "dmsAction", "isOrbit", "classify", "succeeded", "note"]);
const Route = load("Route.js", ["virtualName", "isVirtual", "addressOfVirtual", "isDeviceSink", "addressOfSink", "deviceSink", "virtualSink", "description", "filterArgs", "muteTarget", "ipcLevel", "transportPath", "transportVolume", "iconFor", "popupSize", "popupLayout", "shownLevels"]);

// --- Volume tick (Volume.js) ------------------------------------------------------
eq("same step: no tick", Volume.step(0.61) === Volume.step(0.62), true);
eq("next step: tick", Volume.step(0.62) === Volume.step(0.68), false);
eq("levels are clamped", [Volume.clamp(-1), Volume.clamp(2), Volume.clamp("x")], [0, 1, 0]);
eq("node name ok for pw-play", Volume.validSink("bluez_output.02_00_00_00_10_06.1"), true);
eq("no shell characters", Volume.validSink("x; rm -rf ~"), false);
eq("no option smuggling", Volume.validSink("--target=x y"), false);

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
eq("a sink name never takes colons", [Route.isDeviceSink("bluez_output.AA:BB:CC:DD:EE:01.1"), Route.addressOfSink("alsa_output.usb-Card")], [false, ""]);
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
// The wheel: arcs, icons at the feet, numbers beside the half circles and the gaps all pick a side
eq("wheel on the arcs", [Polar.wheelPart(0, -100, 100, 44, false, true), Polar.wheelPart(0, -44, 100, 44, false, true)], ["device", "pc"]);
eq("wheel on the icons at the feet", [Polar.wheelPart(-100, 14, 100, 44, false, true), Polar.wheelPart(-44, 14, 100, 44, false, true)], ["device", "pc"]);
eq("wheel in the gaps: the nearer arc", [Polar.wheelPart(0, -80, 100, 44, false, true), Polar.wheelPart(0, -60, 100, 44, false, true), Polar.wheelPart(0, -10, 100, 44, false, true), Polar.wheelPart(0, -140, 100, 44, false, true)], ["device", "pc", "pc", "device"]);
eq("wheel on the numbers beside: left device, right this PC", [Polar.wheelPart(-150, -60, 100, 44, true, true), Polar.wheelPart(150, -60, 100, 44, true, true)], ["device", "pc"]);
eq("wheel beside without numbers: the nearer arc", [Polar.wheelPart(-150, -60, 100, 44, false, true), Polar.wheelPart(150, -60, 100, 44, false, true)], ["device", "device"]);
eq("wheel with no device level: always this PC", [Polar.wheelPart(0, -100, 80, 66, false, false), Polar.wheelPart(-150, -60, 80, 66, true, false)], ["pc", "pc"]);
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

done();
