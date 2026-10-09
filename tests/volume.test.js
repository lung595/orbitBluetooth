// Volumes: the tick, the two levels' routing, the vectorscope, smart steps, volume keys.
// Run from the plugin root: gjs tests/volume.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Guide = load("Guide.js", ["url", "connectNote", "blockedNote", "noVolumeNote", "stuckNote", "levelNote"]);
const Volume = load("Volume.js", ["clamp", "step", "validSink", "stepSize", "stepsCrossed", "due", "tickGain", "audible", "tickTargets", "slotsFor", "MAX_TICKS", "MIN_GAP_MS", "TICK_KNEE", "IDLE_MS"]);
const Polar = load("Polar.js", ["LEFT", "TOP", "RIGHT", "slices", "sliceAt", "partOf", "indexOf", "arc", "end", "point", "angleOf", "valueAt", "zone", "wheelPart", "iconSpot", "legendSpot", "parseFrame", "loudness", "spawn", "cavaConfig", "styleOf", "emptyLevels", "levelAt", "reach", "rayAngles", "follow", "heardLevel", "scaleFor", "ease"]);
const Steps = load("Steps.js", ["SPEEDS", "speedOf", "stepAt", "next", "apply", "fixedStep"]);
const Keys = load("Keys.js", ["KEYS", "action", "setArgs", "backArgs", "dmsAction", "isOrbit", "classify", "succeeded", "note"]);
const Route = load("Route.js", ["virtualName", "isVirtual", "addressOfVirtual", "isDeviceSink", "addressOfSink", "deviceSink", "virtualSink", "description", "loopbackArgs", "filterArgs", "muteTarget", "levelNodes", "writeLevel", "writeMuted", "ipcLevel", "transportPath", "transportVolume", "iconFor", "popupSize", "popupLayout", "popupScreen", "shownLevels"]);

// --- Volume tick (Volume.js) ------------------------------------------------------
eq("the setting: 1 % by default, 5 % when it says so", [Volume.stepSize("1"), Volume.stepSize("5"), Volume.stepSize(undefined), Volume.stepSize("7")], [0.01, 0.05, 0.01, 0.01]);
eq("the setting as a number, as Prefs exposes it", [Volume.stepSize(1), Volume.stepSize(5)], [0.01, 0.05]);
eq("a rounding error does not move a step (0.57 is step 57)", [Volume.step(0.57, 0.01), Volume.step(0.29, 0.01), Volume.step(0.35, 0.05)], [57, 29, 7]);
eq("levels are clamped", [Volume.clamp(-1), Volume.clamp(2), Volume.clamp("x")], [0, 1, 0]);
eq("node name ok for pw-play", Volume.validSink("bluez_output.02_00_00_00_10_06.1"), true);
eq("no shell characters", Volume.validSink("x; rm -rf ~"), false);
eq("no option smuggling", Volume.validSink("--target=x y"), false);
// Where the tick plays: the output whose level moved, or every member's for the group's
const tickOne = Volume.stepSize("1"), tickFive = Volume.stepSize("5");
eq("1 %: a tick per percent crossed, up or down", [Volume.stepsCrossed(0.5, 0.5, tickOne), Volume.stepsCrossed(0.5, 0.51, tickOne), Volume.stepsCrossed(0.5, 0.45, tickOne), Volume.stepsCrossed(0.2, 0.5, tickOne)], [0, 1, 5, 30]);
eq("1 %: a change under half a percent crosses nothing", Volume.stepsCrossed(0.5, 0.504, tickOne), 0);
eq("5 %: inside one step no tick, one tick per step across (0.62 is step 12, 0.68 is step 14)", [Volume.stepsCrossed(0.61, 0.62, tickFive), Volume.stepsCrossed(0.62, 0.68, tickFive), Volume.stepsCrossed(0.2, 0.5, tickFive)], [0, 2, 6]);
eq("the ends of the dial are steps too (and levels are clamped)", [Volume.stepsCrossed(0.98, 1.2, tickOne), Volume.stepsCrossed(0.03, -1, tickOne)], [2, 3]);
// Pacing: about 40 a second, a jump is a run that never outlasts 300 ms
eq("at most one tick every 25 ms is 40 a second", 1000 / Volume.MIN_GAP_MS, 40);
eq("a jump is ONE tick, heard live: a long sweep crosses steps but nothing is replayed", Volume.stepsCrossed(0.1, 0.9, tickOne) > 0, true);
eq("a tick is due after the gap, not before", [Volume.due(1000, 0), Volume.due(1024, 1000), Volume.due(1025, 1000), Volume.due(5000, 1000)], [true, false, true, true]);
eq("a clock that went back never blocks the tick", Volume.due(10, 1000), true);
eq("a player outlasts the gap between two ticks", Volume.IDLE_MS > Volume.MIN_GAP_MS * 10, true);
eq("quiet outputs get the tick in full", [Volume.tickGain(0.01), Volume.tickGain(0.3), Volume.tickGain(Volume.TICK_KNEE)], [1, 1, 1]);
eq("above the knee the gain falls so the sound does not grow: gain times level stays at the knee", [0.8, 1].map(v => Math.round(Volume.tickGain(v) * v * 1000) / 1000), [0.6, 0.6]);
eq("at 100 % the tick is 0.6 of itself", Volume.tickGain(1), 0.6);
eq("the gain is never above 1 nor below the 100 % one, even for a broken level", [Volume.tickGain(5), Volume.tickGain(-1), Volume.tickGain(NaN), Volume.tickGain(undefined)], [0.6, 1, 1, 1]);
eq("0 % is silent: nothing to tick in", [Volume.audible(0), Volume.audible(0.001), Volume.audible(-1), Volume.audible(undefined)], [false, true, false, false]);
const at = (name, level) => ({ "name": name, "level": level });
eq("one output: its own sink only, with its gain", Volume.tickTargets([at("bluez_output.AA_BB_CC_DD_EE_01.1", 0.5)]), [{ "name": "bluez_output.AA_BB_CC_DD_EE_01.1", "gain": 1 }]);
eq("the group: every member's sink, each once, each at its own level's gain", Volume.tickTargets([at("a.1", 1), at("b.2", 0.3), at("a.1", 0.3), at("c.3", 0.6)]), [{ "name": "a.1", "gain": 0.6 }, { "name": "b.2", "gain": 1 }, { "name": "c.3", "gain": 1 }]);
eq("never more than four outputs at once", [Volume.MAX_TICKS, Volume.tickTargets(["a", "b", "c", "d", "e", "f"].map(n => at(n, 0.5))).map(t => t.name)], [4, ["a", "b", "c", "d"]]);
eq("a name that is not plain is dropped, the others stay", Volume.tickTargets([at("x; rm -rf ~", 0.5), at("--target=y z", 0.5), at("ok.1", 0.5), at("", 0.5), at(null, 0.5), at(7, 0.5), null]).map(t => t.name), ["ok.1"]);
eq("a silent output (0 %) is left out", Volume.tickTargets([at("a.1", 0), at("b.2", 0.4)]).map(t => t.name), ["b.2"]);
eq("nothing to tick in", [Volume.tickTargets(null), Volume.tickTargets([])], [[], []]);
eq("a sink keeps its player", Volume.slotsFor(["a.1", "b.2", "", ""], ["b.2", "a.1"]), [1, 0]);
eq("a new sink takes a free player", Volume.slotsFor(["a.1", "", "", ""], ["c.3"]), [1]);
eq("with none free it takes one holding a sink not wanted now, never one that is", Volume.slotsFor(["a.1", "b.2", "c.3", "d.4"], ["a.1", "e.5"]), [0, 1]);
eq("two new sinks take two different players", Volume.slotsFor(["a.1", "", "", ""], ["b.2", "c.3"]), [1, 2]);

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
// A level written on the shared PC half reaches every member's copy (D254), nothing else
const node = (volume, muted) => ({ "audio": { "volume": volume, "muted": !!muted } });
const sharedA = node(0.85), sharedB = node(0.85, true), sharedC = node(0.4), own = node(0.3, true);
const shared = [sharedA, sharedB, sharedC];
eq("a shared node reaches all the shared ones", Route.levelNodes(shared, sharedB), shared);
eq("another node reaches only itself", Route.levelNodes(shared, own), [own]);
eq("with nothing shared, only itself", Route.levelNodes([], own), [own]);
Route.writeLevel(shared, sharedC, 0.5);
eq("a level written is on every copy, unmuted", shared.map(n => [n.audio.volume, n.audio.muted]), [[0.5, false], [0.5, false], [0.5, false]]);
eq("and the node outside is left alone", [own.audio.volume, own.audio.muted], [0.3, true]);
Route.writeMuted(shared, sharedA, true);
eq("a mute is on every copy", shared.map(n => n.audio.muted), [true, true, true]);
Route.writeLevel(shared, own, 0.9);
eq("a level on its own node unmutes only it", [own.audio.volume, own.audio.muted, sharedA.audio.volume, sharedA.audio.muted], [0.9, false, 0.5, true]);
eq("ipc up/down in 5 % steps", [Route.ipcLevel("up", 0.5), Route.ipcLevel("down", 0.5), Route.ipcLevel("UP", 0.52)], [0.55, 0.45, 0.55]);
eq("ipc capped at the ends", [Route.ipcLevel("up", 1), Route.ipcLevel("down", 0), Route.ipcLevel("+20", 0.9), Route.ipcLevel("-20", 0.1)], [1, 0, 1, 0]);
eq("ipc absolute and relative", [Route.ipcLevel("40", 0.9), Route.ipcLevel("40%", 0), Route.ipcLevel("+5", 0.4), Route.ipcLevel("-10", 0.4)], [0.4, 0.4, 0.45, 0.3]);
eq("ipc rejects the rest", [Route.ipcLevel("150", 0), Route.ipcLevel("", 0), Route.ipcLevel("abc", 0), Route.ipcLevel("1000000", 0), Route.ipcLevel("4 0", 0), Route.ipcLevel(undefined, 0)], [-1, -1, -1, -1, -1, -1]);
const DEV = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_01";
const tree = "/org/bluez\n/org/bluez/hci0\n" + DEV + "\n" + DEV + "/sep1\n" + DEV + "/sep1/fd0\n/org/bluez/hci0/dev_AA_BB_CC_DD_EE_02/sep1/fd1\n";
eq("transport of the device", Route.transportPath(tree, DEV), DEV + "/sep1/fd0");
// BlueZ 5.87 lists the transport right under the device, the remote endpoints beside it (P162)
const flat = "/org/bluez\n/org/bluez/hci0\n" + DEV + "\n" + DEV + "/fd0\n" + DEV + "/sep1\n" + DEV + "/sep2\n";
eq("transport right under the device", Route.transportPath(flat, DEV), DEV + "/fd0");
eq("an endpoint is not a transport", Route.transportPath("/org/bluez\n" + DEV + "\n" + DEV + "/sep1\n", DEV), "");
eq("no transport: no absolute volume", [Route.transportPath("/org/bluez\n" + DEV + "\n", DEV), Route.transportPath(tree, "/org/bluez/hci0/dev_x")], ["", ""]);
eq("transport volume", [Route.transportVolume('{"type":"q","data":65}'), Route.transportVolume("oops"), Route.transportVolume('{"type":"q","data":300}')], [65, -1, -1]);
eq("level notes say why", [Guide.levelNote("no-device").length > 0, Guide.levelNote("bad-level").indexOf("0 to 100") > 0, Guide.levelNote("no-group").indexOf("together") > 0], [true, true, true]);
// Polar vectorscope (D250, D254, D277): angles clockwise from the right, top = 270
const one = Polar.slices(1)[0];
eq("one outer arc is the whole half circle, lit from the left", [Polar.slices(1), Polar.arc(one, 0.5), Polar.arc(one, 2)], [[{ start: 180, end: 360, reverse: false }], { start: 180, sweep: 90 }, { start: 180, sweep: 180 }]);
eq("two arcs: a gap at the top, the right one lit from its foot", [Polar.slices(2), Polar.arc(Polar.slices(2)[0], 1), Polar.arc(Polar.slices(2)[1], 0.5)], [[{ start: 180, end: 268, reverse: false }, { start: 272, end: 360, reverse: true }], { start: 180, sweep: 88 }, { start: 360, sweep: -44 }]);
eq("three arcs: the middle one lights from the left, the ends toward it",
    Polar.slices(3).map(s => [s.reverse, s.end - s.start]), [[false, 58], [false, 56], [true, 58]]);
eq("four arcs meet in pairs at the top", Polar.slices(4).map(s => [s.start, s.end, s.reverse]),
    [[180, 223, false], [227, 268, false], [272, 313, true], [317, 360, true]]);
eq("a count out of range is clamped", [Polar.slices(0).length, Polar.slices(9).length, Polar.slices(2.9).length], [1, 4, 2]);
eq("every arc's moon starts at its foot and ends at its top end", Polar.slices(4).map(s => [Polar.end(s, 0), Polar.end(s, 1)]), [[180, 223], [227, 268], [313, 272], [360, 317]]);
const pTop = Polar.point(100, 100, 50, 270);
eq("top point", [Math.round(pTop.x), Math.round(pTop.y)], [100, 50]);
eq("which arc an angle belongs to", [Polar.sliceAt(180, 1), Polar.sliceAt(359, 1), Polar.sliceAt(200, 2), Polar.sliceAt(270, 2), Polar.sliceAt(250, 3), Polar.sliceAt(300, 3), Polar.sliceAt(360, 4), Polar.sliceAt(100, 4)], [0, 0, 0, 1, 1, 2, 3, 0]);
eq("parts: the device's own, or one per output", [Polar.partOf(0, 1), Polar.partOf(0, 2), Polar.partOf(3, 4)], ["device", "m0", "m3"]);
eq("arc of a part", ["device", "m0", "m3", "pc", "m4", "second", ""].map(Polar.indexOf), [0, 0, 3, -1, -1, -1, -1]);
eq("drag value", [Polar.valueAt(one, -10, 0), Polar.valueAt(one, 0, -10), Polar.valueAt(one, 10, 0), Polar.valueAt(Polar.slices(1)[0], 7, -7)], [0, 0.5, 1, 0.75]);
eq("below the baseline snaps to the nearer end", [Polar.valueAt(one, 10, 5), Polar.valueAt(one, -10, 5)], [1, 0]);
const two = Polar.slices(2);
eq("two outputs drag: each arc from its foot to the top", [Polar.valueAt(two[0], -10, 0), Polar.valueAt(two[0], 0, -10), Polar.valueAt(two[1], 10, 0), Polar.valueAt(two[1], 0, -10), Math.round(Polar.valueAt(two[0], -10, -10) * 100) / 100, Math.round(Polar.valueAt(two[1], 10, -10) * 100) / 100], [0, 1, 0, 1, 0.51, 0.51]);
eq("zones", [Polar.zone(0, -100, 100, 40, 10, 1), Polar.zone(0, -42, 100, 40, 10, 1), Polar.zone(0, -70, 100, 40, 10, 1), Polar.zone(0, 30, 100, 40, 10, 1)], ["device", "pc", "", ""]);
eq("zones with no outer arc: only this PC's", [Polar.zone(0, -100, 100, 82, 10, 0), Polar.zone(0, -82, 100, 82, 10, 0)], ["", "pc"]);
// A point in the middle of each of four arcs, at the outer radius
const mids = [200, 250, 290, 340].map(d => Polar.point(0, 0, 100, d));
eq("zones: one part per output", mids.map(m => Polar.zone(m.x, m.y, 100, 40, 10, 4)), ["m0", "m1", "m2", "m3"]);
// The wheel: arcs, icons at the feet, numbers beside the half circles and the gaps all pick a side
eq("wheel on the arcs", [Polar.wheelPart(0, -100, 100, 44, false, 1), Polar.wheelPart(0, -44, 100, 44, false, 1)], ["device", "pc"]);
eq("wheel on the icons at the feet", [Polar.wheelPart(-100, 14, 100, 44, false, 1), Polar.wheelPart(-44, 14, 100, 44, false, 1)], ["device", "pc"]);
eq("wheel in the gaps: the nearer arc", [Polar.wheelPart(0, -80, 100, 44, false, 1), Polar.wheelPart(0, -60, 100, 44, false, 1), Polar.wheelPart(0, -10, 100, 44, false, 1), Polar.wheelPart(0, -140, 100, 44, false, 1)], ["device", "pc", "pc", "device"]);
eq("wheel on the numbers beside: left device, right this PC", [Polar.wheelPart(-150, -60, 100, 44, true, 1), Polar.wheelPart(150, -60, 100, 44, true, 1)], ["device", "pc"]);
eq("wheel beside without numbers: the nearer arc", [Polar.wheelPart(-150, -60, 100, 44, false, 1), Polar.wheelPart(150, -60, 100, 44, false, 1)], ["device", "device"]);
eq("wheel with two outputs: each half and its side", [Polar.wheelPart(30, -100, 100, 44, false, 2), Polar.wheelPart(-30, -100, 100, 44, false, 2), Polar.wheelPart(150, -60, 100, 44, true, 2), Polar.wheelPart(-150, -60, 100, 44, true, 2), Polar.wheelPart(30, -44, 100, 44, false, 2)], ["m1", "m0", "m1", "m0", "pc"]);
eq("wheel with four outputs: one per arc", mids.map(m => Polar.wheelPart(m.x, m.y, 100, 44, false, 4)), ["m0", "m1", "m2", "m3"]);
eq("wheel with no device level: always this PC", [Polar.wheelPart(0, -100, 80, 66, false, 0), Polar.wheelPart(-150, -60, 80, 66, true, 0)], ["pc", "pc"]);
// Icons: the first and the last arc at the feet, the others inside their arc by the end they light from
const spots = [0, 1, 2, 3].map(i => Polar.iconSpot(i, 4, 200, 300, 100, 20));
eq("icons: feet for the ends", [spots[0], spots[3]], [{ x: 100, y: 316 }, { x: 300, y: 316 }]);
eq("icons: the middle ones are inside their arc, above the baseline", spots.slice(1, 3).map(s => s.y < 300 && Math.hypot(s.x - 200, s.y - 300) < 100), [true, true]);
eq("icons: the middle ones flank the top", spots[1].x < 200 && spots[2].x > 200, true);
// The legend: outside each arc, leaning away from the centre, one place per arc whatever the levels
const legend = n => [0, 1, 2, 3].slice(0, n).map(i => Polar.legendSpot(i, n, 200, 300, 100, 14));
eq("legend, four outputs: left pair leans left, right pair leans right", legend(4).map(l => l.align), ["right", "right", "left", "left"]);
eq("legend, three outputs: the middle one is centred above the top", legend(3).map(l => l.align), ["right", "center", "left"]);
eq("legend: every label sits just outside its arc", legend(4).concat(legend(3)).map(l => Math.round(Math.hypot(l.x - 200, l.y - 300))), [114, 114, 114, 114, 114, 114, 114]);
eq("legend: the middle label is straight above the centre", [Math.round(legend(3)[1].x), Math.round(legend(3)[1].y)], [200, 186]);
eq("legend: an arc that is gone answers with the last one's place", [Polar.legendSpot(7, 3, 200, 300, 100, 14), Polar.legendSpot(-1, 3, 200, 300, 100, 14)], [Polar.legendSpot(2, 3, 200, 300, 100, 14), Polar.legendSpot(0, 3, 200, 300, 100, 14)]);
eq("legend: no two labels share a place", new Set(legend(4).map(l => Math.round(l.x) + "," + Math.round(l.y))).size, 4);
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
// The screen it shows on (D286): the focused one, never nowhere
eq("pop-up on the focused screen only", Route.popupScreen("focused", "DP-2", ["HDMI-A-1", "DP-2"]), "DP-2");
eq("pop-up on every screen when asked", Route.popupScreen("all", "DP-2", ["HDMI-A-1", "DP-2"]), "");
eq("pop-up on every screen when the focus is unknown or has no pop-up", [Route.popupScreen("focused", "", ["DP-2"]), Route.popupScreen("focused", "eDP-1", ["DP-2"]), Route.popupScreen("focused", "DP-2", [])], ["", "", ""]);
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
    eq("notes: the keys are told as taken, with the way back", [Keys.note("done").action, Keys.note("offer"), Keys.note("nope")], ["Undo", null, null]);
}

done();
