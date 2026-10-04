// Listen together: who may take part, where the sound is taken from, the copy's command.
// Run from the plugin root: gjs tests/together.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const Together = load("Together.js", ["address", "inCall", "refusal", "plan", "delayArg", "cleanDelay", "args", "status"]);
const Guide = load("Guide.js", ["url", "togetherNote"]);

// Made-up devices: a headset, a receiver, a keyboard with no sound, a call-mode headset
const XM = "AA:BB:CC:DD:EE:01", AV = "AA:BB:CC:DD:EE:02", KB = "AA:BB:CC:DD:EE:03", CALL = "AA:BB:CC:DD:EE:04";
const devices = {
    [XM]: { "connected": true, "sink": "bluez_output.AA_BB_CC_DD_EE_01.1", "profile": "a2dp-sink" },
    [AV]: { "connected": true, "sink": "bluez_output.AA_BB_CC_DD_EE_02.1", "profile": "a2dp-sink" },
    [KB]: { "connected": true, "sink": "", "profile": "" },
    [CALL]: { "connected": true, "sink": "bluez_output.AA_BB_CC_DD_EE_04.1", "profile": "headset-head-unit" },
    "AA:BB:CC:DD:EE:05": { "connected": false, "sink": "", "profile": "" }
};
const known = a => devices[a] || null;
const why = (a, b) => (Together.refusal(a, b, known) || {}).why || "";

// --- Who may take part ------------------------------------------------------------
eq("two connected outputs may", why(XM, AV), "");
eq("lower case is accepted", why(XM.toLowerCase(), AV), "");
eq("not an address", [why("x", AV), why(XM, "x; rm -rf"), why(null, undefined), why(XM, "A".repeat(500))], ["bad-address", "bad-address", "bad-address", "bad-address"]);
eq("the same device twice", why(XM, XM.toLowerCase()), "same");
eq("a device Orbit does not see", why(XM, "AA:BB:CC:DD:EE:09"), "not-connected");
eq("a device that is not connected", why(XM, "AA:BB:CC:DD:EE:05"), "not-connected");
eq("a device with no sound output", Together.refusal(XM, KB, known), { "why": "no-audio", "address": KB });
eq("the first is checked too", Together.refusal(KB, AV, known), { "why": "no-audio", "address": KB });
eq("a headset in its call profile", Together.refusal(XM, CALL, known), { "why": "in-call", "address": CALL });
eq("call profiles", [Together.inCall("headset-head-unit"), Together.inCall("headset-head-unit-msbc"), Together.inCall("hfp"), Together.inCall("a2dp-sink"), Together.inCall(""), Together.inCall(undefined)], [true, true, true, false, false, false]);
eq("a sink that is not a Bluetooth output", Together.refusal(XM, AV, a => ({ "connected": true, "sink": "alsa_output.pci-0000", "profile": "" })).why, "no-audio");
eq("address helper", [Together.address(XM.toLowerCase()), Together.address("AA_BB_CC_DD_EE_01"), Together.address(5)], [XM, "AA:BB:CC:DD:EE:01", ""]);

// --- Where the sound comes from -----------------------------------------------------
const sound = a => a === XM ? { "sink": "bluez_output.AA_BB_CC_DD_EE_01.1", "pc": "orbit_pc_AA_BB_CC_DD_EE_01" } : a === AV ? { "sink": "bluez_output.AA_BB_CC_DD_EE_02.1", "pc": "" } : null;
eq("the output in use is the source (its filter is the default)", Together.plan(AV, XM, sound, "orbit_pc_AA_BB_CC_DD_EE_01"), { "source": XM, "other": AV, "capture": "orbit_pc_AA_BB_CC_DD_EE_01", "playback": "bluez_output.AA_BB_CC_DD_EE_02.1" });
eq("a device with no filter copies its own sink", Together.plan(XM, AV, sound, "bluez_output.AA_BB_CC_DD_EE_02.1"), { "source": AV, "other": XM, "capture": "bluez_output.AA_BB_CC_DD_EE_02.1", "playback": "bluez_output.AA_BB_CC_DD_EE_01.1" });
eq("neither in use: the first one", Together.plan(XM, AV, sound, "alsa_output.pci").source, XM);
eq("no default output: the first one", Together.plan(AV, XM, sound, "").source, AV);
eq("both in use at once: the first one", Together.plan(XM, AV, a => ({ "sink": "s", "pc": "d" }), "d").source, XM);

// --- The copy's command ---------------------------------------------------------------
const p = Together.plan(XM, AV, sound, "orbit_pc_AA_BB_CC_DD_EE_01");
const cmd = Together.args(p, 0);
eq("bash watches stdin, data only as positional parameters", [cmd.slice(0, 2), cmd[3], cmd.length], [["bash", "-c"], "orbit", 6]);
eq("the script has no data in it", /AA_BB|orbit_pc/.test(cmd[2]), false);
eq("capture: the filter, passive, never falls back, nothing remembered", [/target\.object=orbit_pc_AA_BB_CC_DD_EE_01 /.test(cmd[4]), /stream\.capture\.sink=true/.test(cmd[4]), /node\.passive=true node\.dont-fallback=true/.test(cmd[4]), /state\.restore-target=false$/.test(cmd[4])], [true, true, true, true]);
eq("playback: the other device's sink, passive, never falls back", [/target\.object=bluez_output\.AA_BB_CC_DD_EE_02\.1 /.test(cmd[5]), /node\.passive=true node\.dont-fallback=true/.test(cmd[5]), /state\.restore-props=false/.test(cmd[5])], [true, true, true]);
eq("no default-sink change, no module", /default|load-module/.test(cmd.join(" ")), false);
eq("a delay goes in as the third parameter, in seconds", Together.args(p, 120)[6], "0.120");
eq("delay capped and cleaned", [Together.delayArg(0), Together.delayArg(-5), Together.delayArg("x"), Together.delayArg(9999), Together.delayArg(33.4), Together.cleanDelay(9999), Together.cleanDelay("abc"), Together.cleanDelay(40.6)], ["", "", "", "0.500", "0.033", 500, 0, 41]);
eq("a node name that is not a BlueZ output or an Orbit filter: no command", [Together.args({ "capture": "x y", "playback": p.playback }), Together.args({ "capture": p.capture, "playback": "a; b" }), Together.args({ "capture": "--help", "playback": p.playback }), Together.args(null)], [null, null, null, null]);
eq("status", [JSON.parse(Together.status(null)).active, JSON.parse(Together.status({ "first": XM, "second": AV, "source": XM, "delayMs": 40 })).from], [false, XM]);

// --- Notes (value 10) -----------------------------------------------------------------
const guide = new TextDecoder().decode(GLib.file_get_contents(root + "/docs/GUIDE.md")[1]);
const anchors = guide.split("\n").filter(l => /^#{2,3} /.test(l)).map(l => l.replace(/^#+ /, "").toLowerCase().replace(/[^a-z0-9 -]/g, "").replace(/ /g, "-"));
["same", "bad-address", "not-connected", "no-audio", "in-call", "member-left", "link-stopped", "none", "unknown"].forEach(w => {
    const n = Guide.togetherNote(w, "WH-1000XM6");
    eq("note " + w + " says what and what to do", !!(n.title && n.hint), true);
    eq("note " + w + " links to a real section", anchors.indexOf(n.anchor) >= 0, true);
});
eq("the multipoint note exists in the guide", anchors.indexOf("works-with-multipoint-headsets") >= 0, true);
eq("a name goes in the title", Guide.togetherNote("not-connected", "WH-1000XM6").title, "WH-1000XM6 is not connected");
eq("guide url", Guide.url("listen-together"), "https://github.com/lung595/orbitBluetooth/blob/main/docs/GUIDE.md#listen-together");

done();
