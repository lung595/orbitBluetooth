// Listen together: who may take part, where the sound is taken from, the copies' commands.
// Run from the plugin root: gjs tests/together.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const Together = load("Together.js");
const Guide = load("Guide.js", ["url", "togetherNote"]);
const Polar = load("Polar.js", ["slices", "indexOf"]);

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
eq("delay capped and cleaned", [Together.delayArg(0), Together.delayArg(-5), Together.delayArg("x"), Together.delayArg(9999), Together.delayArg(33.4), Together.cleanDelay(9999), Together.cleanDelay("abc"), Together.cleanDelay(40.6)], ["", "", "", "1.000", "0.033", 1000, 0, 41]);
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
eq("capped", Together.withDelay({}, [XM, AV], AV, 9999), { [AV]: 1000 });
eq("not a member: unchanged", Together.withDelay({ [AV]: 20 }, [XM, AV], SP1, 90), { [AV]: 20 });
eq("a member that left loses its delay", Together.withDelay({ [AV]: 20, [SP1]: 30 }, [XM, AV], XM, 0), { [AV]: 20 });
eq("garbage address", Together.withDelay({}, [XM, AV], "x", 5), {});

eq("delays of members that are gone are dropped", Together.prune({ [AV]: 20, [SP1]: 30 }, [XM, SP1]), { [SP1]: 30 });

// --- A list typed on the command line ---------------------------------------------------------
eq("commas, spaces or both", [Together.parseList(XM + "," + AV), Together.parseList(XM + " " + AV + "  " + SP1), Together.parseList(" " + XM + ", " + AV + " ")], [[XM, AV], [XM, AV, SP1], [XM, AV]]);
eq("nothing, or too long to be addresses", [Together.parseList(""), Together.parseList("   "), Together.parseList(undefined), Together.parseList(("A".repeat(17) + ",").repeat(40)), Together.parseList(7)], [[], [], [], [], []]);
eq("an injected text stays one bad item", Together.refusal(Together.parseList(XM + "; reboot"), known).why, "bad-address");

// --- Status (IPC) --------------------------------------------------------------------------
eq("no session", JSON.parse(Together.status(null)), { "active": false, "members": [], "from": "", "delaysMs": {} });
eq("a session", JSON.parse(Together.status({ "members": [XM, AV, SP1], "source": XM, "delays": { [AV]: 40 } })), { "active": true, "members": [XM, AV, SP1], "from": XM, "delaysMs": { [AV]: 40 } });

// --- Wired members (D298): a session can hold wired outputs, alone or beside Bluetooth ones ------------
// Made-up wired outputs: a USB headset, an audio interface, an unplugged one, one with no sink
const W1 = "alsa_output.usb-Acme_Demo_Headset-00.analog-stereo", W2 = "alsa_output.usb-Acme_Studio_Interface_0000-00.HiFi__Line__sink";
const W3 = "alsa_output.pci-0000_00_00.0.analog-stereo", WOFF = "alsa_output.usb-Acme_Unplugged-00.analog-stereo", WMUTE = "alsa_output.usb-Acme_Silent-00.analog-stereo";
const wired = { "connected": true, "sink": "", "profile": "" };
const wiredDevices = {
    [W1]: { ...wired, "sink": W1 }, [W2]: { ...wired, "sink": W2 }, [W3]: { ...wired, "sink": W3 },
    [WOFF]: { "connected": false, "sink": "", "profile": "" },
    [WMUTE]: wired
};
const knownAll = a => devices[a] || wiredDevices[a] || null;
const whyAll = list => (Together.refusal(list, knownAll) || {}).why || "";
// What Orbit sees when one member's output is not what it should be
const withSink = (who, sink, profile) => a => a === who ? { "connected": true, "sink": sink, "profile": profile || "" } : knownAll(a);
const joinWhyAll = (members, newcomers) => (Together.joinRefusal(members, newcomers, knownAll) || {}).why || "";

eq("two wired outputs may", whyAll([W1, W2]), "");
eq("a wired output and a Bluetooth one may", [whyAll([W1, XM]), whyAll([XM, W1]), whyAll([XM, W1, W2, AV])], ["", "", ""]);
eq("the cap is four, wired or not", [whyAll([W1, W2, W3, XM]), whyAll([W1, W2, W3, XM, AV])], ["", "too-many"]);
eq("the same wired output twice", Together.refusal([W1, XM, W1], knownAll), { "why": "same", "address": W1 });
eq("a wired output that is not plugged in", Together.refusal([XM, WOFF], knownAll), { "why": "not-connected", "address": WOFF });
eq("a wired output Orbit does not see", whyAll([XM, "alsa_output.usb-Acme_Nowhere-00.analog-stereo"]), "not-connected");
eq("a wired output with no sink", Together.refusal([XM, WMUTE], knownAll), { "why": "no-audio", "address": WMUTE });
eq("a wired output whose sink is a Bluetooth one, or is not a sink name", [Together.refusal([XM, W1], withSink(W1, sinkOf(AV))).why, Together.refusal([XM, W1], withSink(W1, "alsa_output.x; y")).why], ["no-audio", "no-audio"]);
eq("a Bluetooth device with a wired sink is no Bluetooth output", Together.refusal([XM, AV], withSink(AV, W1)), { "why": "no-audio", "address": AV });
eq("a wired output has no call profile, whatever the profile says", Together.refusal([XM, W1], withSink(W1, W1, "headset-head-unit")), null);
eq("a Bluetooth device in a call is still refused beside a wired one", Together.refusal([W1, CALL], knownAll), { "why": "in-call", "address": CALL });
eq("a name that is not an address or a wired output", [whyAll([W1, "x"]), whyAll([W1, "alsa_output.x; rm -rf"]), whyAll([W1, "alsa_output.a..b"]), whyAll([W1, "alsa_output.has space"]), whyAll([W1, "alsa_output." + "a".repeat(300)]), whyAll([W1, "alsa_input.usb-x"]), whyAll([W1, "bluez_output.AA_BB_CC_DD_EE_02.1"]), whyAll([W1, "alsa_output."])], ["bad-address", "bad-address", "bad-address", "bad-address", "bad-address", "bad-address", "bad-address", "bad-address"]);
eq("wired members: too few", whyAll([W1]), "too-few");
eq("the injected name is never asked about", (() => { const asked = []; Together.refusal([XM, "alsa_output.x; rm -rf"], a => { asked.push(a); return knownAll(a); }); return asked; })(), []);

eq("a wired output joins a session", joinWhyAll([XM, AV], [W1]), "");
eq("a Bluetooth device joins wired members", joinWhyAll([W1, W2], [XM]), "");
eq("a wired member is already in", Together.joinRefusal([XM, W1], [W1], knownAll), { "why": "already", "address": W1 });
eq("the same wired newcomer twice", joinWhyAll([XM, AV], [W1, W1]), "same");
eq("a fifth member is refused whatever it is", joinWhyAll([XM, AV, W1, W2], [W3]), "too-many");
eq("a newcomer that is not plugged in or has no sink", [joinWhyAll([XM, AV], [WOFF]), joinWhyAll([XM, AV], [WMUTE])], ["not-connected", "no-audio"]);
eq("a bad newcomer", joinWhyAll([XM, AV], ["alsa_output.x y"]), "bad-address");
eq("a wired member that is unplugged does not block a join (it stays a member)", joinWhyAll([XM, WOFF], [W1]), "");

eq("member helper", [Together.member(W1), Together.member(XM.toLowerCase()), Together.member("alsa_output.x; y"), Together.member(5)], [W1, XM, "", ""]);
eq("the address helper stays Bluetooth only", [Together.address(W1), Together.address(XM)], ["", XM]);
eq("a drop joins a wired output to a Bluetooth one, either order", [Together.merge([XM, AV], W1, AV), Together.merge([XM, AV], AV, W1), Together.merge([], W1, XM), Together.merge([XM, W1], W1, XM)], [[XM, AV, W1], [XM, AV, W1], [W1, XM], [XM, W1]]);
eq("a bad drop adds nothing", Together.merge([XM, AV], "alsa_output.x; y", W1), [XM, AV, W1]);
eq("a wired member leaves", [Together.without([XM, W1, AV], W1), Together.without([XM, W1], "alsa_output.x; y")], [[XM, AV], [XM, W1]]);

// The sounds: XM has a PC-level filter, wired outputs never do
const soundAll = a => devices[a] ? sound(a) : wiredDevices[a] && wiredDevices[a].sink ? { "sink": wiredDevices[a].sink, "pc": "", "profile": "" } : null;
const pw = Together.plan([XM, W1, AV], soundAll, filter(XM));
eq("a Bluetooth source is copied to a wired output and to a Bluetooth one", pw, {
    "source": XM,
    "taps": [
        { "member": W1, "capture": filter(XM), "playback": W1 },
        { "member": AV, "capture": filter(XM), "playback": sinkOf(AV) }
    ]
});
const pwSrc = Together.plan([XM, W1, AV], soundAll, W1);
eq("the wired default output is the source: it copies its own sink, no filter", pwSrc, {
    "source": W1,
    "taps": [
        { "member": XM, "capture": W1, "playback": sinkOf(XM) },
        { "member": AV, "capture": W1, "playback": sinkOf(AV) }
    ]
});
eq("two wired outputs, the second one in use", Together.plan([W1, W2], soundAll, W2), { "source": W2, "taps": [{ "member": W1, "capture": W2, "playback": W1 }] });
eq("none in use: the first member, wired or not", [Together.plan([W1, XM], soundAll, "alsa_output.pci-0000").source, Together.plan([XM, W1], soundAll, "").source], [W1, XM]);
eq("an unplugged or silent wired member has no copy and stays in the session", Together.plan([XM, WOFF, WMUTE, W1], soundAll, filter(XM)).taps.map(t => t.member), [W1]);
eq("the source's own output away: the next member with an output is the source", Together.plan([WOFF, W1, XM], soundAll, "").source, W1);
const soundWith = (who, sink, profile) => a => a === who ? { "sink": sink, "pc": "", "profile": profile || "" } : soundAll(a);
eq("a wired member whose sink is a Bluetooth one has no copy", Together.plan([XM, W1], soundWith(W1, sinkOf(AV)), filter(XM)).taps, []);
eq("a Bluetooth member whose sink is a wired one has no copy", Together.plan([XM, AV], soundWith(AV, W1), filter(XM)).taps, []);
eq("a Bluetooth member in a call has no copy beside a wired source", Together.plan([W1, CALL], soundAll, W1).taps, []);
eq("a wired member never counts as in a call, whatever the profile says", Together.plan([XM, W1], soundWith(W1, W1, "headset-head-unit"), filter(XM)).taps.map(t => t.member), [W1]);

// The commands of copies that touch a wired output
const wcmd = Together.args(pw.taps[0], 0);
eq("a copy to a wired output: bash, positional parameters, six items", [wcmd.slice(0, 2), wcmd[3], wcmd.length], [["bash", "-c"], "orbit", 6]);
eq("the wired playback targets its sink, passive, never falls back", [wcmd[5].indexOf("target.object=" + W1 + " ") >= 0, /node\.passive=true node\.dont-fallback=true/.test(wcmd[5]), /state\.restore-props=false/.test(wcmd[5])], [true, true, true]);
eq("the wired copy has node names of its own, safe in a property string", [/^node\.name=orbit_together_w_usb_acme_demo_he_[0-9a-f]{16}_in target\.object=orbit_pc_AA_BB_CC_DD_EE_01 /.test(wcmd[4]), /^node\.name=orbit_together_w_usb_acme_demo_he_[0-9a-f]{16}_out target\.object=/.test(wcmd[5])], [true, true]);
eq("the script has no data in it", /usb|alsa|AA_BB/.test(wcmd[2]), false);
eq("no node name has a character that splits a property string", wcmd.slice(4).every(s => !/["'{},;$`\\]/.test(s)), true);
eq("a wired capture is accepted: a wired source", Together.args(pwSrc.taps[0], 0)[4].indexOf("target.object=" + W1 + " ") >= 0, true);
eq("a copy between two wired outputs", Together.args({ "member": W1, "capture": W2, "playback": W1 }, 0) !== null, true);
eq("a wired delay goes in as the third parameter", Together.args(pw.taps[0], 175)[6], "0.175");
eq("a Bluetooth copy keeps its old key and node names", [/node\.name=orbit_together_AA_BB_CC_DD_EE_02_in /.test(Together.args(pw.taps[1], 0)[4]), /node\.name=orbit_together_AA_BB_CC_DD_EE_02_out /.test(Together.args(pw.taps[1], 0)[5])], [true, true]);
eq("two wired outputs never share node names", Together.args({ "member": W1, "capture": W3, "playback": W1 }, 0)[4].split(" ")[0] !== Together.args({ "member": W2, "capture": W3, "playback": W2 }, 0)[4].split(" ")[0], true);
eq("an injected or malformed name: no command", [
    Together.args({ "member": W1, "capture": filter(XM), "playback": "alsa_output.x; rm -rf" }),
    Together.args({ "member": W1, "capture": "alsa_output.x y", "playback": W1 }),
    Together.args({ "member": W1, "capture": "alsa_output.a..b", "playback": W1 }),
    Together.args({ "member": W1, "capture": filter(XM), "playback": "alsa_output." + "a".repeat(200) }),
    Together.args({ "member": W1, "capture": filter(XM), "playback": "alsa_output.x\"y" }),
    Together.args({ "member": W1, "capture": filter(XM), "playback": "alsa_input.usb-x" }),
    Together.args({ "member": "alsa_output.x; rm -rf", "capture": filter(XM), "playback": W1 }),
    Together.args({ "member": "alsa_output.", "capture": filter(XM), "playback": W1 }),
    Together.args({ "member": W1, "capture": "--help", "playback": W1 })
], [null, null, null, null, null, null, null, null, null]);
eq("a copy of an output to itself would feed back: no command", [Together.args({ "member": W1, "capture": W1, "playback": W1 }), Together.args({ "member": AV, "capture": sinkOf(AV), "playback": sinkOf(AV) })], [null, null]);

const wcmds = Together.commands(pw, { [W1]: 175, [AV]: 40 });
eq("one command per copy, keyed by the wired or Bluetooth member, with its own delay", [wcmds.map(c => c.key), wcmds[0].command[6], wcmds[1].command[6]], [[W1, AV], "0.175", "0.040"]);
const wrunning = {};
wcmds.forEach(c => { wrunning[c.key] = c.command; });
eq("nothing changed with a wired member: nothing to do", Together.diff(wrunning, wcmds), { "stop": [], "start": [] });
eq("a wired newcomer starts one copy and cuts none", [Together.diff(wrunning, Together.commands(Together.plan([XM, W1, AV, W2], soundAll, filter(XM)), { [W1]: 175, [AV]: 40 })).stop, Together.diff(wrunning, Together.commands(Together.plan([XM, W1, AV, W2], soundAll, filter(XM)), { [W1]: 175, [AV]: 40 })).start.map(w => w.key)], [[], [W2]]);
eq("a new delay restarts the wired copy only", [Together.diff(wrunning, Together.commands(pw, { [W1]: 190, [AV]: 40 })).stop, Together.diff(wrunning, Together.commands(pw, { [W1]: 190, [AV]: 40 })).start.map(w => w.key)], [[W1], [W1]]);
eq("a wired member that leaves stops its copy only", Together.diff(wrunning, wcmds.slice(1)).stop, [W1]);

eq("delays of a wired member", [Together.withDelay({}, [XM, W1], W1, 120), Together.withDelay({ [W1]: 120 }, [XM, W1], W1, 0), Together.withDelay({}, [XM, W1], W1, 9999), Together.withDelay({}, [XM, W1], W2, 90), Together.withDelay({}, [XM, W1], "alsa_output.x; y", 5)], [{ [W1]: 120 }, {}, { [W1]: 1000 }, {}, {}]);
eq("a wired member that left loses its delay", Together.prune({ [W1]: 20, [AV]: 30 }, [XM, AV]), { [AV]: 30 });

eq("a list typed with wired names", [Together.parseList(W1 + "," + XM), Together.parseList(W1 + " " + W2 + "  " + XM + " " + W3)], [[W1, XM], [W1, W2, XM, W3]]);
eq("four of the longest names still fit a list", Together.parseList(new Array(4).fill("alsa_output." + "a".repeat(148)).join(",")).length, 4);
eq("a list too long to hold four members is nothing", Together.parseList(new Array(5).fill("alsa_output." + "a".repeat(148)).join(",")), []);
eq("an injected wired name stays one bad item", Together.refusal(Together.parseList(W1 + "; reboot"), knownAll).why, "bad-address");
eq("status keeps wired members as they are", JSON.parse(Together.status({ "members": [XM, W1], "source": W1, "delays": { [W1]: 40 } })), { "active": true, "members": [XM, W1], "from": W1, "delaysMs": { [W1]: 40 } });

// --- Notes (value 10) -----------------------------------------------------------------
const guide = new TextDecoder().decode(GLib.file_get_contents(root + "/docs/GUIDE.md")[1]);
const anchors = guide.split("\n").filter(l => /^#{2,3} /.test(l)).map(l => l.replace(/^#+ /, "").toLowerCase().replace(/[^a-z0-9 -]/g, "").replace(/ /g, "-"));
const reasons = ["same", "bad-address", "not-connected", "no-audio", "in-call", "too-few", "too-many", "outside", "already", "in-group", "not-member", "source", "no-session", "member-out", "member-left", "link-stopped", "none", "unknown"];
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
eq("the cap note quotes the cap", Guide.togetherNote("too-many", "").title.includes(String(Together.MAX_MEMBERS)), true);
// One cap for the session, the arcs of the volume wheel and the part names of the IPC
const last = Together.MAX_MEMBERS - 1;
eq("the wheel has an arc for every member and no more", [Polar.slices(Together.MAX_MEMBERS).length, Polar.slices(Together.MAX_MEMBERS + 3).length], [Together.MAX_MEMBERS, Together.MAX_MEMBERS]);
eq("the last member has a part, the next one has none", [Polar.indexOf("m" + last), Polar.indexOf("m" + Together.MAX_MEMBERS)], [last, -1]);
eq("a delay is cleaned once for every caller", [Together.delayArg(9999), Together.delayArg(-5), Together.delayArg(40)], [(Together.MAX_DELAY_MS / 1000).toFixed(3), "", "0.040"]);
eq("guide url", Guide.url("listen-together"), "https://github.com/lung595/orbitBluetooth/blob/main/docs/GUIDE.md#listen-together");

done();
