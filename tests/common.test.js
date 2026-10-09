// Shared rules: address forms and the guide links (Address.js, Guide.js).
// Run from the plugin root: gjs tests/common.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const Guide = load("Guide.js", ["url", "connectNote", "blockedNote", "noVolumeNote", "stuckNote", "copyLevelNote", "levelNote"]);
const Address = load("Address.js", ["key", "colon", "find", "isDevicePath"]);

// Address forms and BlueZ paths, in one place (Address.js)
eq("address key: either form, any case", [Address.key("aa:bb:cc:dd:ee:01"), Address.key("AA_BB_CC_DD_EE_01")], ["AA_BB_CC_DD_EE_01", "AA_BB_CC_DD_EE_01"]);
eq("address key: not an address", [Address.key("AA:BB"), Address.key("AA:BB:CC:DD:EE:0G"), Address.key("x; rm -rf"), Address.key(null), Address.key(undefined)], ["", "", "", "", ""]);
eq("address with colons", [Address.colon("aa_bb_cc_dd_ee_01"), Address.colon("nope")], ["AA:BB:CC:DD:EE:01", ""]);
eq("address found in a BlueZ path", Address.find("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_01"), "AA:BB:CC:DD:EE:01");
eq("address found in a HID_UNIQ value, either separator", [Address.find("aa:bb:cc:dd:ee:01"), Address.find("aa-bb-cc-dd-ee-01")], ["AA:BB:CC:DD:EE:01", "AA:BB:CC:DD:EE:01"]);
eq("no address in the text, or mixed separators", [Address.find("BAT0"), Address.find(""), Address.find(undefined), Address.find("aa:bb-cc_dd:ee-01")], ["", "", "", ""]);
eq("path ok", Address.isDevicePath("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"), true);
eq("path: injection", Address.isDevicePath("/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF; rm"), false);
eq("path: option", Address.isDevicePath("--help"), false);
eq("path: empty", Address.isDevicePath(undefined), false);
eq("path: adapter number capped at three digits", [Address.isDevicePath("/org/bluez/hci999/dev_AA_BB_CC_DD_EE_FF"), Address.isDevicePath("/org/bluez/hci1000/dev_AA_BB_CC_DD_EE_FF")], [true, false]);

// Guide links (value 10): every anchor used must exist in docs/GUIDE.md
const guide = new TextDecoder().decode(GLib.file_get_contents(root + "/docs/GUIDE.md")[1]);
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
eq("a copy with no level of its own says why, and where to read more", [Guide.copyLevelNote("Marantz").title, anchors.indexOf(Guide.copyLevelNote("Marantz").anchor) >= 0, !!Guide.copyLevelNote("Marantz").hint], ["Marantz has no volume of its own", true, true]);
eq("a nameless copy", Guide.copyLevelNote("").title, "This device has no volume of its own");
eq("a nameless device stuck", Guide.stuckNote("").title, "This device is still connected");
["noise-control", "pairing-safety", "if-it-does-not-connect", "if-it-does-not-disconnect", "bluetooth-is-off", "the-two-volumes", "new-headphones-pop-up"].forEach(a => eq("guide has #" + a, anchors.indexOf(a) >= 0, true));
eq("guide url", Guide.url("noise-control"), "https://github.com/lung595/orbitBluetooth/blob/main/docs/GUIDE.md#noise-control");
eq("a nameless device", Guide.connectNote("pair", "").title, "Could not pair this device");

// --- Wired outputs (D298): the notes that say it in their own words (value 10) --------------------
const All = load("Guide.js");
const WIRED = "alsa_output.usb-Acme_Demo_Headset-00.analog-stereo", PHONES = "AA:BB:CC:DD:EE:01";
const wiredReasons = ["not-connected", "member-out", "member-left", "source"];
wiredReasons.forEach(w => {
    const n = All.togetherNote(w, "Interface", WIRED);
    eq("wired " + w + " says what and what to do", !!(n.title && n.hint), true);
    eq("wired " + w + " is told in its own words", [n.title, n.hint].join(" ") !== [All.togetherNote(w, "Interface", PHONES).title, All.togetherNote(w, "Interface", PHONES).hint].join(" "), true);
    eq("wired " + w + " links to a section that exists", anchors.indexOf(n.anchor) >= 0, true);
    eq("wired " + w + " names the output by its name, not its node", [n.title.indexOf("Interface") >= 0, JSON.stringify(n).indexOf("alsa_output")], [true, -1]);
});
eq("an output that is gone was unplugged, not disconnected", [All.togetherNote("member-out", "Interface", WIRED).title, All.togetherNote("member-left", "Interface", WIRED).title], ["Interface was unplugged", "Interface was unplugged"]);
eq("the others keep going, or the session ended with it", [/keep listening/.test(All.togetherNote("member-out", "x", WIRED).hint), /ended/.test(All.togetherNote("member-left", "x", WIRED).hint)], [true, true]);
eq("an output that is not there is not plugged in, and is told to plug it in", [All.togetherNote("not-connected", "Interface", WIRED).title, /Plug it in/.test(All.togetherNote("not-connected", "Interface", WIRED).hint)], ["Interface is not plugged in", true]);
eq("the output the sound comes from points to the nudge in the settings", [All.togetherNote("source", "Interface", WIRED).anchor, /Wired delay/.test(All.togetherNote("source", "Interface", WIRED).hint)], ["wired-delay", true]);
eq("a nameless wired output", [All.togetherNote("member-out", "", WIRED).title, All.togetherNote("not-connected", undefined, WIRED).title], ["This output was unplugged", "This output is not plugged in"]);
// A Bluetooth device is still connected and disconnected, as before
eq("a Bluetooth device keeps its own words", [All.togetherNote("member-out", "XM6", PHONES), All.togetherNote("not-connected", "XM6", PHONES).title], [All.togetherNote("member-out", "XM6"), "XM6 is not connected"]);
eq("a Bluetooth source's note is the one it was", [All.togetherNote("source", "XM6", PHONES).anchor, All.togetherNote("source", "XM6", PHONES).title], ["limits", "XM6 is where the sound comes from"]);
// An output that reports no delay is told in the same words for either kind, with the same guide link
eq("a Bluetooth output with no delay is told so", [All.togetherNote("no-latency", "XM6", PHONES).title, All.togetherNote("no-latency", "XM6", PHONES).anchor], ["XM6 reports no delay", "limits"]);
eq("a Bluetooth output with no delay says what to do by hand", /togetherDelay/.test(All.togetherNote("no-latency", "XM6", PHONES).hint), true);
eq("a nameless output with no delay", All.togetherNote("no-latency", "", PHONES).title, "This device reports no delay");
// What a wired output has no other way to say reads the same as for a Bluetooth one
["same", "too-few", "too-many", "outside", "already", "in-group", "not-member", "no-session", "no-audio", "in-call", "bad-address", "link-stopped", "none", "unknown"].forEach(w => {
    eq("wired " + w + " reads as it does for any device", All.togetherNote(w, "Interface", WIRED), All.togetherNote(w, "Interface"));
});
// Only a token that is a member picks the wired wording: a half-written one is nothing
eq("a token that is not a member's does not change the words", [All.togetherNote("member-out", "x", "alsa_output.a b"), All.togetherNote("member-out", "x", "alsa_output.a..b"), All.togetherNote("member-out", "x", null), All.togetherNote("member-out", "x", 5)], new Array(4).fill(All.togetherNote("member-out", "x")));

done();
