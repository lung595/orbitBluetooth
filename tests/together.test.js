// Listen together: who may take part, where the sound is taken from, the copies' commands.
// Run from the plugin root: gjs tests/together.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const Together = load("Together.js");
const Guide = load("Guide.js", ["url", "togetherNote"]);

// Made-up devices: a headset, a receiver, two speakers, a fifth output, a keyboard
// with no sound, a call-mode headset and one that is not connected
const XM = "AA:BB:CC:DD:EE:01", AV = "AA:BB:CC:DD:EE:02", KB = "AA:BB:CC:DD:EE:03", CALL = "AA:BB:CC:DD:EE:04";
const OFF = "AA:BB:CC:DD:EE:05", SP1 = "AA:BB:CC:DD:EE:06", SP2 = "AA:BB:CC:DD:EE:07", SP3 = "AA:BB:CC:DD:EE:08";
const sinkOf = a => "bluez_output." + a.replace(/:/g, "_") + ".1";
const speaker = a => ({ "connected": true, "sink": sinkOf(a), "profile": "a2dp-sink" });
const devices = {
    [XM]: speaker(XM), [AV]: speaker(AV), [SP1]: speaker(SP1), [SP2]: speaker(SP2), [SP3]: speaker(SP3),
    [KB]: { "connected": true, "sink": "", "profile": "" },
    [CALL]: { "connected": true, "sink": sinkOf(CALL), "profile": "headset-head-unit" },
    [OFF]: { "connected": false, "sink": "", "profile": "" }
};
const known = a => devices[a] || null;
const why = list => (Together.refusal(list, known) || {}).why || "";
const joinWhy = (members, newcomers) => (Together.joinRefusal(members, newcomers, known) || {}).why || "";

// --- Who may take part ------------------------------------------------------------
eq("two connected outputs may", why([XM, AV]), "");
eq("three and four may", [why([XM, AV, SP1]), why([XM, AV, SP1, SP2])], ["", ""]);
eq("five may not (the cap is four)", why([XM, AV, SP1, SP2, SP3]), "too-many");
eq("one is not a session", [why([XM]), why([])], ["too-few", "too-few"]);
eq("lower case is accepted", why([XM.toLowerCase(), AV]), "");
eq("not an address", [why(["x", AV]), why([XM, "x; rm -rf"]), why([null, undefined]), why([XM, "A".repeat(500)]), why("AA:BB:CC:DD:EE:01"), why(null), why([XM, 5])], ["bad-address", "bad-address", "bad-address", "bad-address", "bad-address", "bad-address", "bad-address"]);
eq("a huge list is refused before it is read", why(new Array(1000).fill(XM)), "bad-address");
eq("the same device twice", Together.refusal([XM, AV, XM.toLowerCase()], known), { "why": "same", "address": XM });
eq("a device Orbit does not see", why([XM, "AA:BB:CC:DD:EE:09"]), "not-connected");
eq("a device that is not connected", Together.refusal([XM, OFF], known), { "why": "not-connected", "address": OFF });
eq("a device with no sound output", Together.refusal([XM, KB], known), { "why": "no-audio", "address": KB });
eq("every member is checked, the first one too", Together.refusal([KB, AV, SP1], known), { "why": "no-audio", "address": KB });
eq("a headset in its call profile", Together.refusal([XM, AV, CALL], known), { "why": "in-call", "address": CALL });
eq("call profiles", [Together.inCall("headset-head-unit"), Together.inCall("headset-head-unit-msbc"), Together.inCall("hfp"), Together.inCall("a2dp-sink"), Together.inCall(""), Together.inCall(undefined)], [true, true, true, false, false, false]);
eq("a sink that is not a Bluetooth output", why([XM, AV].map(a => a)) === "" && Together.refusal([XM, AV], a => ({ "connected": true, "sink": "alsa_output.pci-0000", "profile": "" })).why, "no-audio");
eq("address helper", [Together.address(XM.toLowerCase()), Together.address("AA_BB_CC_DD_EE_01"), Together.address(5), Together.address("A".repeat(40))], [XM, XM, "", ""]);

// --- Joining a session that exists ------------------------------------------------
eq("a connected output joins", joinWhy([XM, AV], [SP1]), "");
eq("two newcomers may join at once", joinWhy([XM, AV], [SP1, SP2]), "");
eq("a member is already in", Together.joinRefusal([XM, AV], [AV], known), { "why": "already", "address": AV });
eq("the same newcomer twice", joinWhy([XM, AV], [SP1, SP1.toLowerCase()]), "same");
eq("a fifth is refused with the cap message", joinWhy([XM, AV, SP1, SP2], [SP3]), "too-many");
eq("two newcomers past the cap", joinWhy([XM, AV, SP1], [SP2, SP3]), "too-many");
eq("a newcomer with no sound, not connected, in a call", [joinWhy([XM, AV], [KB]), joinWhy([XM, AV], [OFF]), joinWhy([XM, AV], [CALL])], ["no-audio", "not-connected", "in-call"]);
eq("nobody to join", [joinWhy([XM, AV], []), joinWhy([XM, AV], ["x"]), joinWhy([XM, AV], "x")], ["bad-address", "bad-address", "bad-address"]);
eq("a member whose output is away does not block a join (multipoint, D279)", joinWhy([XM, KB], [SP1]), "");

// --- Members that come and go ------------------------------------------------------
eq("a drop onto a member adds the newcomer", Together.merge([XM, AV], SP1, AV), [XM, AV, SP1]);
eq("a drop of a member onto a newcomer adds it too", Together.merge([XM, AV], AV, SP1), [XM, AV, SP1]);
eq("a first drop makes the pair, in the order given", Together.merge([], XM, AV), [XM, AV]);
eq("a repeat adds nothing", Together.merge([XM, AV], XM, AV), [XM, AV]);
eq("one leaves", [Together.without([XM, AV, SP1], AV), Together.without([XM, AV], AV.toLowerCase()), Together.without([XM, AV], SP1)], [[XM, SP1], [XM], [XM, AV]]);

// --- Where the sound comes from -----------------------------------------------------
const filter = a => "orbit_pc_" + a.replace(/:/g, "_");
// XM and SP1 have a PC-level filter, the others do not
const sound = a => devices[a] && devices[a].sink ? { "sink": devices[a].sink, "pc": a === XM || a === SP1 ? filter(a) : "", "profile": devices[a].profile } : null;
const p3 = Together.plan([XM, AV, SP1], sound, filter(XM));
eq("the output in use is the source, one copy per other member", p3, {
    "source": XM,
    "taps": [
        { "member": AV, "capture": filter(XM), "playback": sinkOf(AV) },
        { "member": SP1, "capture": filter(XM), "playback": sinkOf(SP1) }
    ]
});
eq("a source with no filter copies its own sink", Together.plan([XM, AV], sound, sinkOf(AV)), {
    "source": AV, "taps": [{ "member": XM, "capture": sinkOf(AV), "playback": sinkOf(XM) }]
});
eq("the default is a member's sink itself", Together.plan([XM, AV], sound, sinkOf(XM)).source, XM);
eq("none in use: the first one", Together.plan([AV, XM], sound, "alsa_output.pci").source, AV);
eq("no default output: the first one", Together.plan([AV, XM], sound, "").source, AV);
eq("all in use at once: the first one", Together.plan([XM, AV], a => ({ "sink": sinkOf(a), "pc": "orbit_pc_AA_BB_CC_DD_EE_09", "profile": "" }), "orbit_pc_AA_BB_CC_DD_EE_09").source, XM);
eq("a member whose output is away has no copy and stays in the session (D279)", Together.plan([XM, AV, KB], sound, filter(XM)).taps.map(t => t.member), [AV]);
eq("a member in a call has no copy either", Together.plan([XM, AV, CALL], sound, filter(XM)).taps.map(t => t.member), [AV]);
eq("the source's output away: the next member is the source", Together.plan([KB, AV, SP1], sound, "").source, AV);
eq("nobody has an output: no source, no copy", Together.plan([KB, "AA:BB:CC:DD:EE:09"], sound, ""), { "source": KB, "taps": [] });
eq("a member Orbit no longer sees", Together.plan([XM, "AA:BB:CC:DD:EE:09"], sound, filter(XM)).taps, []);
eq("nobody", Together.plan([], sound, ""), { "source": "", "taps": [] });

// --- The copies' commands ---------------------------------------------------------------
const tap = p3.taps[0];
const cmd = Together.args(tap, 0);
eq("bash watches stdin, data only as positional parameters", [cmd.slice(0, 2), cmd[3], cmd.length], [["bash", "-c"], "orbit", 6]);
eq("the script has no data in it", /AA_BB|orbit_pc/.test(cmd[2]), false);
eq("capture: the filter, passive, never falls back, nothing remembered", [/target\.object=orbit_pc_AA_BB_CC_DD_EE_01 /.test(cmd[4]), /stream\.capture\.sink=true/.test(cmd[4]), /node\.passive=true node\.dont-fallback=true/.test(cmd[4]), /state\.restore-target=false$/.test(cmd[4])], [true, true, true, true]);
eq("playback: the member's sink, passive, never falls back", [/target\.object=bluez_output\.AA_BB_CC_DD_EE_02\.1 /.test(cmd[5]), /node\.passive=true node\.dont-fallback=true/.test(cmd[5]), /state\.restore-props=false/.test(cmd[5])], [true, true, true]);
eq("each copy has its own node names", [/node\.name=orbit_together_AA_BB_CC_DD_EE_02_in /.test(cmd[4]), /node\.name=orbit_together_AA_BB_CC_DD_EE_02_out /.test(cmd[5])], [true, true]);
eq("no default-sink change, no module", /default|load-module/.test(cmd.join(" ")), false);
eq("a delay goes in as the third parameter, in seconds", Together.args(tap, 120)[6], "0.120");
eq("delay capped and cleaned", [Together.delayArg(0), Together.delayArg(-5), Together.delayArg("x"), Together.delayArg(9999), Together.delayArg(33.4), Together.cleanDelay(9999), Together.cleanDelay("abc"), Together.cleanDelay(40.6)], ["", "", "", "0.500", "0.033", 500, 0, 41]);
eq("a node name that is not a BlueZ output or an Orbit filter: no command", [Together.args({ "member": AV, "capture": "x y", "playback": tap.playback }), Together.args({ "member": AV, "capture": tap.capture, "playback": "a; b" }), Together.args({ "member": AV, "capture": "--help", "playback": tap.playback }), Together.args({ "member": "x", "capture": tap.capture, "playback": tap.playback }), Together.args(null)], [null, null, null, null, null]);

const cmds = Together.commands(p3, { [SP1]: 80 });
eq("one command per copy, keyed by member, each with its own delay", [cmds.map(c => c.key), cmds[0].command[6], cmds[1].command[6]], [[AV, SP1], undefined, "0.080"]);
eq("no plan, no command", [Together.commands(null, {}), Together.commands({ "source": "", "taps": [] }, {})], [[], []]);

// --- Starting and stopping only what changed (a newcomer never cuts the others) ---------------
const running = {};
cmds.forEach(c => { running[c.key] = c.command; });
eq("nothing changed: nothing to do", Together.diff(running, cmds), { "stop": [], "start": [] });
const delays = { [SP1]: 80 };
const grown = Together.commands(Together.plan([XM, AV, SP1, SP2], sound, filter(XM)), delays);
eq("a newcomer starts one copy and stops none", [Together.diff(running, grown).stop, Together.diff(running, grown).start.map(w => w.key)], [[], [SP2]]);
eq("a member that left stops its copy only", [Together.diff(running, cmds.slice(0, 1)).stop, Together.diff(running, cmds.slice(0, 1)).start], [[SP1], []]);
const changed = Together.diff(running, Together.commands(p3, { [AV]: 40, [SP1]: 80 }));
eq("a new delay restarts that copy only", [changed.stop, changed.start.map(w => w.key)], [[AV], [AV]]);
const moved = Together.diff(running, Together.commands(Together.plan([XM, AV, SP1], sound, sinkOf(AV)), delays));
eq("a new source stops the copy it no longer needs and restarts the others", [moved.stop, moved.start.map(w => w.key)], [[AV, SP1], [XM, SP1]]);
eq("no copies wanted: everything stops", Together.diff(running, []), { "stop": [AV, SP1], "start": [] });
eq("from nothing", Together.diff({}, cmds).start.length, 2);

// --- Delays of members -------------------------------------------------------------------
eq("a delay for a member", Together.withDelay({}, [XM, AV], AV, 120), { [AV]: 120 });
eq("0 clears it", Together.withDelay({ [AV]: 120 }, [XM, AV], AV, 0), {});
eq("capped", Together.withDelay({}, [XM, AV], AV, 9999), { [AV]: 500 });
eq("not a member: unchanged", Together.withDelay({ [AV]: 20 }, [XM, AV], SP1, 90), { [AV]: 20 });
eq("a member that left loses its delay", Together.withDelay({ [AV]: 20, [SP1]: 30 }, [XM, AV], XM, 0), { [AV]: 20 });
eq("garbage address", Together.withDelay({}, [XM, AV], "x", 5), {});

// --- Status (IPC) --------------------------------------------------------------------------
eq("no session", JSON.parse(Together.status(null)), { "active": false, "members": [], "from": "", "delaysMs": {} });
eq("a session", JSON.parse(Together.status({ "members": [XM, AV, SP1], "source": XM, "delays": { [AV]: 40 } })), { "active": true, "members": [XM, AV, SP1], "from": XM, "delaysMs": { [AV]: 40 } });

// --- Notes (value 10) -----------------------------------------------------------------
const guide = new TextDecoder().decode(GLib.file_get_contents(root + "/docs/GUIDE.md")[1]);
const anchors = guide.split("\n").filter(l => /^#{2,3} /.test(l)).map(l => l.replace(/^#+ /, "").toLowerCase().replace(/[^a-z0-9 -]/g, "").replace(/ /g, "-"));
const reasons = ["same", "bad-address", "not-connected", "no-audio", "in-call", "too-few", "too-many", "already", "not-member", "no-session", "member-out", "member-left", "link-stopped", "none", "unknown"];
reasons.forEach(w => {
    const n = Guide.togetherNote(w, "WH-1000XM6");
    eq("note " + w + " says what and what to do", !!(n.title && n.hint), true);
    eq("note " + w + " links to a real section", anchors.indexOf(n.anchor) >= 0, true);
    eq("note " + w + " does not limit a session to two", w === "too-few" || !/\btwo\b/i.test(n.title + " " + n.hint), true);
});
eq("every reason has a note of its own", reasons.filter(w => w !== "unknown" && w !== "link-stopped").every(w => Guide.togetherNote(w, "x").title !== Guide.togetherNote("unknown", "x").title), true);
eq("the multipoint note exists in the guide", anchors.indexOf("works-with-multipoint-headsets") >= 0, true);
eq("a name goes in the title", Guide.togetherNote("not-connected", "WH-1000XM6").title, "WH-1000XM6 is not connected");
eq("the cap note says how many and what to do", [/4/.test(Guide.togetherNote("too-many", "").title), /Leave together/.test(Guide.togetherNote("too-many", "").hint)], [true, true]);
eq("guide url", Guide.url("listen-together"), "https://github.com/lung595/orbitBluetooth/blob/main/docs/GUIDE.md#listen-together");

done();
