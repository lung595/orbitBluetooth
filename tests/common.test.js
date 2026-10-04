// Shared rules: address forms and the guide links (Address.js, Guide.js).
// Run from the plugin root: gjs tests/common.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done, root, GLib } = imports.lib;

const Guide = load("Guide.js", ["url", "connectNote", "blockedNote", "noVolumeNote", "stuckNote", "levelNote"]);
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
eq("a nameless device stuck", Guide.stuckNote("").title, "This device is still connected");
["noise-control", "pairing-safety", "if-it-does-not-connect", "if-it-does-not-disconnect", "bluetooth-is-off", "the-two-volumes", "new-headphones-pop-up"].forEach(a => eq("guide has #" + a, anchors.indexOf(a) >= 0, true));
eq("guide url", Guide.url("noise-control"), "https://github.com/lung595/orbitBluetooth/blob/main/docs/GUIDE.md#noise-control");
eq("a nameless device", Guide.connectNote("pair", "").title, "Could not pair this device");

done();
