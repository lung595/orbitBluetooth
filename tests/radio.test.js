// The shared-radio warning: which outputs play, which pair is told about, and when.
// Run from the plugin root: gjs tests/radio.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const Radio = load("Radio.js", ["playing", "sharedKey", "outputCount", "due"]);
const Guide = load("Guide.js", ["radioNote"]);

// Made-up devices: a headset, a receiver, a speaker on another adapter
const XM = "AA:BB:CC:DD:EE:01", AV = "AA:BB:CC:DD:EE:02", ELSEWHERE = "AA:BB:CC:DD:EE:09";
const sinkOf = a => "bluez_output." + a.replace(/:/g, "_") + ".1";
const known = { [XM]: true, [AV]: true };
const run = (address, active) => ({ "sink": sinkOf(address), "active": active });

// Who plays
eq("nothing plays", Radio.playing([], known), []);
eq("one output plays", Radio.playing([run(XM, true)], known), [XM]);
eq("two play, sorted", Radio.playing([run(AV, true), run(XM, true)], known), [XM, AV]);
eq("a paused link is not playing", Radio.playing([run(XM, true), run(AV, false)], known), [XM]);
eq("two links into one output count once", Radio.playing([run(XM, true), run(XM, true)], known), [XM]);
eq("an output of another adapter has its own radio", Radio.playing([run(XM, true), run(ELSEWHERE, true)], known), [XM]);
eq("a sink that is not Bluetooth is ignored", Radio.playing([{ "sink": "alsa_output.pci-0000_01_00.1.hdmi-stereo", "active": true }, run(XM, true)], known), [XM]);
eq("Orbit's own filter is not an output", Radio.playing([{ "sink": "orbit_pc_AA_BB_CC_DD_EE_01", "active": true }, run(XM, true)], known), [XM]);
eq("no links, no map, junk entries", [Radio.playing(null, known), Radio.playing([run(XM, true)], null), Radio.playing([null, undefined, {}], known)], [[], [], []]);

// The pair that shares the radio
eq("one output alone shares nothing", Radio.sharedKey([run(XM, true)], known), "");
eq("two outputs share, whatever the order", Radio.sharedKey([run(AV, true), run(XM, true)], known), XM + "+" + AV);
eq("two outputs, one paused: nothing shared", Radio.sharedKey([run(XM, true), run(AV, false)], known), "");

// Whether there is anything to watch
const node = (name, extra) => Object.assign({ "name": name, "isSink": true, "isStream": false }, extra || {});
eq("two Bluetooth outputs exist", Radio.outputCount([node(sinkOf(XM)), node(sinkOf(AV))], known), 2);
eq("a stream into a sink is not an output", Radio.outputCount([node(sinkOf(XM)), node(sinkOf(AV), { "isStream": true })], known), 1);
eq("a source is not an output", Radio.outputCount([node(sinkOf(XM)), node(sinkOf(AV), { "isSink": false })], known), 1);
eq("a loopback and the other adapter's output do not count", Radio.outputCount([node(sinkOf(XM)), node("orbit_pc_AA_BB_CC_DD_EE_01"), node(sinkOf(ELSEWHERE))], known), 1);
eq("no nodes", [Radio.outputCount(null, known), Radio.outputCount([], known)], [0, 0]);

// When to say it: a pair, the orbit open, not told yet
const pair = XM + "+" + AV;
eq("a new pair, orbit open: say it", Radio.due(pair, [], true), true);
eq("orbit closed: wait", Radio.due(pair, [], false), false);
eq("already told: stay quiet", Radio.due(pair, [pair], true), false);
eq("another pair is told on its own", Radio.due(pair, [XM + "+" + ELSEWHERE], true), true);
eq("no pair, nothing to say", Radio.due("", [], true), false);

// The note: short, says what to do, links to a real guide section (value 10)
const note = Guide.radioNote();
const [, bytes] = GLib.file_get_contents(root + "/docs/GUIDE.md");
const guide = new TextDecoder().decode(bytes);
const anchors = guide.split("\n").filter(l => /^#{2,3} /.test(l)).map(l => l.replace(/^#+ /, "").toLowerCase().replace(/[^a-z0-9 -]/g, "").replace(/ /g, "-"));
eq("the note names the problem and the way out", [note.title, !!note.hint], ["Two outputs share one Bluetooth radio", true]);
eq("the note links to a real section", anchors.indexOf(note.anchor) >= 0, true);

done();
