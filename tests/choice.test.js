// The group chooser: which outputs it lists, what can be ticked and why not, and what validating asks for.
// Run from the plugin root: gjs tests/choice.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Choice = load("Choice.js");
const Together = load("Together.js");

// Made-up Bluetooth devices: three that play sound, a mouse, a headset in its call
// profile, earbuds whose output is not there yet and a pair that is not connected
const XM = "AA:BB:CC:DD:EE:01", AV = "AA:BB:CC:DD:EE:02", SP1 = "AA:BB:CC:DD:EE:03", MOUSE = "AA:BB:CC:DD:EE:04";
const CALL = "AA:BB:CC:DD:EE:05", BUDS = "AA:BB:CC:DD:EE:06", OFF = "AA:BB:CC:DD:EE:07";
// Made-up wired outputs: a USB headset, a USB interface, a screen, the sound card, and one unplugged since the read
const W1 = "alsa_output.usb-Acme_Pulse_Headset_0000-00.analog-stereo";
const W2 = "alsa_output.usb-Acme_Studio_2x2-00.HiFi__Line1__sink";
const W3 = "alsa_output.pci-0000_01_00.1.hdmi-stereo";
const W4 = "alsa_output.pci-0000_00_1f.3.analog-stereo";
const W5 = "alsa_output.usb-Acme_Gone_0000-00.analog-stereo";

// What the session knows of each (Together.memberRefusal asks it)
const sinkOf = a => "bluez_output." + a.replace(/:/g, "_") + ".1";
const speaker = a => ({ "connected": true, "sink": sinkOf(a), "profile": "a2dp-sink" });
const wire = a => ({ "connected": true, "sink": a, "profile": "" });
const devices = {
    [XM]: speaker(XM), [AV]: speaker(AV), [SP1]: speaker(SP1),
    [MOUSE]: { "connected": true, "sink": "", "profile": "" }, [BUDS]: { "connected": true, "sink": "", "profile": "" },
    [CALL]: { "connected": true, "sink": sinkOf(CALL), "profile": "headset-head-unit" },
    [OFF]: { "connected": false, "sink": "", "profile": "" },
    [W1]: wire(W1), [W2]: wire(W2), [W3]: wire(W3), [W4]: wire(W4)
};
const refusal = who => Together.memberRefusal(who, a => devices[a] || null);

const plug = (sink, label, bus, formFactor) => ({ "sink": sink, "label": label, "bus": bus, "formFactor": formFactor, "plugged": true });
const wired = [plug(W1, "Acme Pulse Headset", "usb", "headset"), plug(W2, "Acme Studio 2x2", "usb", ""), plug(W3, "Display Audio", "pci", ""), plug(W4, "Built-in Audio", "pci", "internal")];
const body = (address, name, kind) => ({ "address": address, "name": name, "kind": kind });
const bluetooth = [
    body(XM, "Studio Headphones", "headphonesSlim"), body(AV, "Living Room Bar", "soundbar"), body(SP1, "Kitchen Speaker", "speaker"),
    body(MOUSE, "Desk Mouse", "mouseErgo"), body(CALL, "Call Headset", "headset"), body(BUDS, "Pocket Buds", "earbudsRound"),
    body(OFF, "Spare Buds", "earbudsStem")
];
const base = { "wired": wired, "bluetooth": bluetooth, "members": [], "chosen": [XM], "refusal": refusal };
const view = over => Choice.build(Object.assign({}, base, over));
const ids = v => v.sections.map(s => [s.id, s.rows.map(r => r.id)]);
const row = (v, id) => v.sections.flatMap(s => s.rows).find(r => r.id === id);
const whys = (v, list) => list.map(id => row(v, id).why);

// --- What is listed ----------------------------------------------------------------------
const v = view();
eq("two sections, the wired outputs first, each sorted by name", ids(v), [["wired", [W1, W2, W4, W3]], ["bluetooth", [CALL, SP1, AV, BUDS, XM]]]);
eq("the sections are titled", v.sections.map(s => s.title), ["Wired", "Bluetooth"]);
eq("a device that is not connected is not offered", row(v, OFF), undefined);
eq("a mouse is not offered: it never plays sound", row(v, MOUSE), undefined);
eq("an output unplugged since the list was read is not offered", ids(view({ "wired": wired.concat([plug(W5, "Gone", "usb", "")]) })), ids(v));
eq("an empty section is not drawn", [ids(view({ "wired": [] })).map(s => s[0]), ids(view({ "bluetooth": [] })).map(s => s[0])], [["bluetooth"], ["wired"]]);
eq("nothing to list, nothing drawn", [view({ "wired": [], "bluetooth": [] }).sections, view({ "wired": [], "bluetooth": [] }).enough], [[], false]);

// --- Rows, pictures and why a row cannot be ticked ----------------------------------------
eq("a wired output is drawn by how it is connected", [W1, W2, W3, W4].map(id => row(v, id).icon), ["usb", "usb", "settings_input_hdmi", "speaker"]);
eq("a Bluetooth device by its kind", [XM, AV, SP1, CALL, BUDS].map(id => row(v, id).icon), ["headphones", "speaker_group", "speaker", "headset_mic", "earbuds"]);
eq("a kind with no picture of its own gets the generic one", [view({ "bluetooth": [body(XM, "A", "tv")] }), view({ "bluetooth": [body(XM, "A", "constructor")] }), view({ "bluetooth": [body(XM, "A", undefined)] })].map(x => row(x, XM).icon), ["bluetooth", "bluetooth", "bluetooth"]);
eq("a row that can be ticked says nothing", whys(v, [W1, XM, AV, SP1]), ["", "", "", ""]);
eq("a headset in its call profile is shown, with why it cannot be ticked", [row(v, CALL).why, row(v, CALL).caption], ["in-call", "Call mode"]);
eq("audio whose output is not there yet is shown too", [row(v, BUDS).why, row(v, BUDS).caption], ["no-audio", "No sound yet"]);
eq("the row of a name is its label", [row(v, XM).label, row(v, W1).label], ["Studio Headphones", "Acme Pulse Headset"]);
eq("the clicked device is ticked to begin with, the others are not", [row(v, XM).ticked, row(v, AV).ticked, row(v, W1).ticked], [true, false, false]);

// --- What is ticked ------------------------------------------------------------------------
eq("a click ticks, a second click unticks", [Choice.toggle([XM], SP1), Choice.toggle([XM, SP1], XM), Choice.toggle([], W1)], [[XM, SP1], [SP1], [W1]]);
eq("what is ticked keeps the order it was ticked in", Choice.toggle(Choice.toggle([XM], W2), AV), [XM, W2, AV]);
eq("what cannot be ticked is dropped from what is ticked", view({ "chosen": [XM, CALL, BUDS, MOUSE, OFF, "junk", W2] }).chosen, [XM, W2]);
eq("an output that is not there is dropped too", view({ "chosen": [XM, W5] }).chosen, [XM]);
eq("a repeat is one tick, however long the list", [view({ "chosen": [XM, XM, AV] }).chosen, view({ "chosen": new Array(1000).fill(XM) }).chosen], [[XM, AV], [XM]]);
eq("what is ticked is not a list when it is not one", [view({ "chosen": "x" }).chosen, view({ "chosen": null }).chosen, view({ "chosen": { "length": 3 } }).chosen], [[], [], []]);

// --- The cap ----------------------------------------------------------------------------------
const full = view({ "chosen": [XM, AV, SP1, W1] });
eq("the cap is the session's", Together.MAX_MEMBERS, 4);
eq("with the cap reached, the others cannot be ticked, and say so", [whys(full, [W2, W3, W4]), row(full, W2).caption], [["full", "full", "full"], "Group is full"]);
eq("what is ticked can still be unticked when the group is full", whys(full, [XM, AV, SP1, W1]), ["", "", "", ""]);
eq("a row with a reason of its own keeps it when the group is full", whys(full, [CALL, BUDS]), ["in-call", "no-audio"]);
eq("one place left: nothing is full", whys(view({ "chosen": [XM, AV, SP1] }), [W1, W2, W3, W4]), ["", "", "", ""]);
eq("more than the cap ticked: only what fits stays, in order", view({ "chosen": [XM, AV, SP1, W1, W2, W3] }).chosen, [XM, AV, SP1, W1]);

// --- A group that exists -------------------------------------------------------------------------
const joined = view({ "members": [XM, W1], "chosen": [SP1] });
eq("a member is shown ticked and locked, and says it is in", [XM, W1].map(id => [row(joined, id).ticked, row(joined, id).locked, row(joined, id).why, row(joined, id).caption]), [[true, true, "already", "In the group"], [true, true, "already", "In the group"]]);
eq("a newcomer is a row like any other", [row(joined, SP1).ticked, row(joined, SP1).locked, row(joined, SP1).why], [true, false, ""]);
eq("a member is never in what is ticked", view({ "members": [XM, W1], "chosen": [XM, SP1, W1] }).chosen, [SP1]);
eq("the members take places: two are left", [whys(view({ "members": [XM, W1], "chosen": [SP1, AV] }), [W2, W3, W4]), view({ "members": [XM, W1], "chosen": [SP1, AV, W2] }).chosen], [["full", "full", "full"], [SP1, AV]]);
eq("a full group has no place for anyone", [whys(view({ "members": [XM, AV, SP1, W1], "chosen": [] }), [W2, W3, W4]), view({ "members": [XM, AV, SP1, W1], "chosen": [W2] }).chosen], [["full", "full", "full"], []]);
eq("a member in its call profile is still a member", [row(view({ "members": [XM, CALL] }), CALL).locked, row(view({ "members": [XM, CALL] }), CALL).why], [true, "already"]);
eq("a lone member is no session: the group is made anew", [view({ "members": [XM], "chosen": [XM] }).chosen, row(view({ "members": [XM] }), XM).locked], [[XM], false]);

// --- Is there anything to make a group of ---------------------------------------------------------
eq("a group needs two outputs to tick", [view({ "wired": [], "bluetooth": [body(XM, "Solo", "speaker")] }).enough, view({ "wired": [wired[0]], "bluetooth": [body(XM, "Solo", "speaker")] }).enough], [false, true]);
eq("outputs that cannot be ticked do not count", view({ "wired": [], "bluetooth": [body(XM, "A", "headset"), body(CALL, "B", "headset"), body(MOUSE, "C", "mouseErgo")] }).enough, false);
eq("a group there is needs one to add", [view({ "members": [XM, AV], "wired": [], "bluetooth": [body(XM, "A", "speaker"), body(AV, "B", "speaker")] }).enough, view({ "members": [XM, AV], "wired": [], "bluetooth": [body(XM, "A", "speaker"), body(AV, "B", "speaker"), body(SP1, "C", "speaker")] }).enough], [false, true]);

// --- Hostile or broken data (value 11) -------------------------------------------------------------
const hostile = view({
    "wired": [
        plug("alsa_output.x; rm -rf /", "Shell", "usb", ""), plug("alsa_output..x", "Path trick", "usb", ""), plug("alsa_output." + "a".repeat(200), "Long", "usb", ""),
        plug(XM, "A Bluetooth address", "usb", ""), plug("", "Nothing", "", ""), plug(undefined, "Undefined", "", ""), null, "text", 5, { "label": "No sink" }
    ],
    "bluetooth": [
        body("x", "Not an address", "speaker"), body(W1, "A wired name", "speaker"), body("AA:BB:CC:DD:EE:01; reboot", "Command", "speaker"), body(undefined, "Undefined", "speaker"), null, 7, "text"
    ]
});
eq("nothing hostile is offered", hostile.sections, []);
eq("a Bluetooth address is read in any spelling", ids(view({ "wired": [], "bluetooth": [body(XM.toLowerCase(), "Low", "speaker"), body("AA_BB_CC_DD_EE_02", "Underscores", "speaker")] })), [["bluetooth", [XM, AV]]]);
eq("the same output twice is one row", ids(view({ "wired": [wired[0], wired[0]], "bluetooth": [bluetooth[0], bluetooth[0], body(XM.toLowerCase(), "Again", "speaker")] })), [["wired", [W1]], ["bluetooth", [XM]]]);
const messy = view({ "wired": [plug(W1, "  Zero​width‮\u0007\n  name  ", "usb", "")], "bluetooth": [body(XM, "x".repeat(100), "speaker"), body(AV, "", "speaker"), body(SP1, undefined, "speaker")] });
eq("a name is cleaned of what cannot be seen and kept short", [row(messy, W1).label, row(messy, XM).label.length], ["Zero width name", 40]);
eq("a device with no name shows its address", [row(messy, AV).label, row(messy, SP1).label], [AV, SP1]);
eq("any input that is not a list gives nothing", [{}, null, undefined, "x", 5, { "wired": "x", "bluetooth": 5, "members": "x", "chosen": {} }].map(i => Choice.build(i).sections), [[], [], [], [], [], []]);
eq("without a way to ask the session, everything is offered", ids(Choice.build({ "wired": wired, "bluetooth": [body(MOUSE, "Desk Mouse", "mouseErgo")], "chosen": [] })), [["wired", [W1, W2, W4, W3]], ["bluetooth", [MOUSE]]]);
const members = [XM, W1], chosen = [SP1];
const given = JSON.stringify([wired, bluetooth, members, chosen]);
view({ "members": members, "chosen": chosen });
Choice.toggle(chosen, AV);
Choice.outcome(members, chosen);
eq("what is given is never changed", JSON.stringify([wired, bluetooth, members, chosen]), given);
eq("two outputs with one name keep a stable order, and case does not matter", ids(view({ "wired": [plug(W2, "alpha", "usb", ""), plug(W1, "Alpha", "usb", ""), plug(W3, "Beta", "pci", "")], "bluetooth": [] })), [["wired", [W1, W2, W3]]]);

// --- What validating asks of the session -------------------------------------------------------------
eq("two ticked make a group", Choice.outcome([], [XM, W1]), { "mode": "start", "list": [XM, W1], "why": "" });
eq("one ticked is not a group", [Choice.outcome([], [XM]).why, Choice.outcome([], []).why], ["pick-more", "pick-more"]);
eq("the order ticked is the order given", Choice.outcome([], [W2, XM, AV]).list, [W2, XM, AV]);
eq("the newcomers are added to a group that exists", Choice.outcome([XM, AV], [SP1, W1]), { "mode": "add", "list": [SP1, W1], "why": "" });
eq("a member ticked is not added twice", Choice.outcome([XM, AV], [XM, SP1]).list, [SP1]);
eq("adding nobody is not an addition", [Choice.outcome([XM, AV], []).why, Choice.outcome([XM, AV], [XM]).why], ["pick-more", "pick-more"]);
eq("nothing given, nothing asked", [Choice.outcome(null, null), Choice.outcome("x", { "length": 2 })], [{ "mode": "start", "list": [], "why": "pick-more" }, { "mode": "start", "list": [], "why": "pick-more" }]);
eq("a lone member is no group: a new one is made", Choice.outcome([XM], [AV, SP1]), { "mode": "start", "list": [AV, SP1], "why": "" });

// --- The words -----------------------------------------------------------------------------------------
eq("no group yet: it is created", [Choice.labels([]).entry, Choice.labels(null).title, Choice.labels([XM]).action], ["Create a group…", "Create a group", "Listen together"]);
eq("a group there is: outputs are added", [Choice.labels([XM, AV]).entry, Choice.labels([XM, AV]).title, Choice.labels([XM, AV]).action], ["Add to the group…", "Add to the group", "Add"]);
eq("the entry is the title and an ellipsis", [[], [XM, AV]].every(m => Choice.labels(m).entry === Choice.labels(m).title + "…"), true);
eq("on a member's own menu the entry adds another device, the member is in the group already", [Choice.labels([XM, AV], true).entry, Choice.labels([XM, AV], true).title, Choice.labels([XM, AV], true).action], ["Add a device…", "Add to the group", "Add"]);
eq("only a group there is has a member: with none the entry still creates one", [Choice.labels([], true).entry, Choice.labels([XM], true).entry], ["Create a group…", "Create a group…"]);
eq("anything but true is not a member (a missing answer keeps the usual words)", [undefined, null, 1, "yes"].map(x => Choice.labels([XM, AV], x).entry), ["Add to the group…", "Add to the group…", "Add to the group…", "Add to the group…"]);
eq("every word is said", [[], [XM, AV]].every(m => Object.values(Choice.labels(m)).every(w => typeof w === "string" && w.length > 0)), true);
eq("the captions are short", Object.values(Choice.CAPTIONS).every(c => c.length <= 14), true);
eq("no word limits a group to two", [[], [XM, AV]].every(m => !/\btwo\b/i.test(Object.values(Choice.labels(m)).join(" "))), true);

done();
