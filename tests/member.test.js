// Members of Listen together: a Bluetooth address or a wired (ALSA) output, as one validated token.
// Run from the plugin root: gjs tests/member.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Member = load("Member.js");

// Made-up outputs: a USB headset, an audio interface, a sound card
const BT = "AA:BB:CC:DD:EE:01";
const USB = "alsa_output.usb-Acme_Demo_Headset-00.analog-stereo";
const IFACE = "alsa_output.usb-Acme_Studio_Interface_0000-00.HiFi__Line__sink";
const CARD = "alsa_output.pci-0000_00_00.0.analog-stereo";

// --- Which kind of member -------------------------------------------------------------
eq("a Bluetooth address", Member.kind(BT), "bluetooth");
eq("a wired output", [Member.kind(USB), Member.kind(IFACE), Member.kind(CARD)], ["wired", "wired", "wired"]);
eq("the kind helpers agree", [Member.isWired(USB), Member.isWired(BT), Member.isWired("x")], [true, false, false]);
eq("anything else is no kind", [Member.kind(""), Member.kind("x"), Member.kind(null), Member.kind(undefined), Member.kind(5), Member.kind({}), Member.kind([BT])], ["", "", "", "", "", "", ""]);
eq("a Bluetooth sink is not a member of its own", Member.kind("bluez_output.AA_BB_CC_DD_EE_01.1"), "");

// --- Cleaning a token ---------------------------------------------------------------
eq("an address is spelled with colons, in capitals", [Member.clean(BT.toLowerCase()), Member.clean("AA_BB_CC_DD_EE_01"), Member.clean(BT)], [BT, BT, BT]);
eq("a wired name stays as it is, case included", [Member.clean(USB), Member.clean(IFACE), Member.clean("alsa_output.X")], [USB, IFACE, "alsa_output.X"]);
eq("every mark of a real name is allowed", Member.clean("alsa_output.usb-A_b+c.1-2"), "alsa_output.usb-A_b+c.1-2");
eq("only the name after the prefix, at least one character", [Member.clean("alsa_output."), Member.clean("alsa_output"), Member.clean("alsa_input.usb-x")], ["", "", ""]);
eq("spaces are refused, around the name too", [Member.clean(USB + " "), Member.clean(" " + USB), Member.clean("alsa_output.usb x"), Member.clean("alsa_output.a\tb"), Member.clean("alsa_output.a\nb")], ["", "", "", "", ""]);
eq("a command is refused", [Member.clean("alsa_output.x; rm -rf"), Member.clean("alsa_output.x;rm"), Member.clean("alsa_output.$(id)"), Member.clean("alsa_output.`id`"), Member.clean("alsa_output.x|y"), Member.clean("alsa_output.x&y"), Member.clean("alsa_output.x\\y")], ["", "", "", "", "", "", ""]);
eq("quotes, braces, commas and equal signs are refused (they split a property string)", [Member.clean("alsa_output.x\"y"), Member.clean("alsa_output.x'y"), Member.clean("alsa_output.x{y}"), Member.clean("alsa_output.x,y"), Member.clean("alsa_output.x=y"), Member.clean("alsa_output.x:y"), Member.clean("alsa_output.x/y")], ["", "", "", "", "", "", ""]);
eq("a path trick is refused", [Member.clean("alsa_output..x"), Member.clean("alsa_output.x..y"), Member.clean("alsa_output.x.."), Member.clean("alsa_output..")], ["", "", "", ""]);
eq("a single dot is a name like any other", Member.clean("alsa_output.x.y"), "alsa_output.x.y");
eq("accents and other scripts are refused", [Member.clean("alsa_output.café"), Member.clean("alsa_output.テスト")], ["", ""]);
eq("the longest token is 160, no more", [Member.clean("alsa_output." + "a".repeat(148)).length, Member.clean("alsa_output." + "a".repeat(149)), Member.clean("alsa_output." + "a".repeat(5000))], [160, "", ""]);
eq("garbage is no token", [Member.clean(""), Member.clean("x"), Member.clean(null), Member.clean(undefined), Member.clean(5), Member.clean({}), Member.clean([USB]), Member.clean("A".repeat(500))], ["", "", "", "", "", "", "", ""]);

// --- The key in a node name ------------------------------------------------------------
eq("a Bluetooth key is the address with underscores", [Member.key(BT), Member.key(BT.toLowerCase()), Member.key("AA_BB_CC_DD_EE_01")], ["AA_BB_CC_DD_EE_01", "AA_BB_CC_DD_EE_01", "AA_BB_CC_DD_EE_01"]);
eq("not a member, no key", [Member.key("x"), Member.key(""), Member.key(null), Member.key("alsa_output.x; y"), Member.key("alsa_output.a..b"), Member.key("alsa_output." + "a".repeat(200))], ["", "", "", "", "", ""]);

const keys = [USB, IFACE, CARD].map(Member.key);
eq("a wired key is lower case letters, digits and underscores only", keys.every(k => /^w_[a-z0-9_]+$/.test(k)), true);
eq("a wired key is short and keeps a readable start", [keys[0].length <= 40, /^w_usb_acme_demo_he_[0-9a-f]{16}$/.test(keys[0]), /^w_pci_0000_00_00_0_[0-9a-f]{16}$/.test(keys[2])], [true, true, true]);
eq("the key is the same every time", [Member.key(USB), Member.key(USB)], [keys[0], keys[0]]);
eq("keys of different outputs differ", new Set(keys).size, 3);
eq("a long name still gives a short key", Member.key("alsa_output." + "a".repeat(148)).length <= 40, true);
eq("names that start alike are told apart", Member.key("alsa_output.usb-Acme_Demo_Headset-00.analog-stereo") !== Member.key("alsa_output.usb-Acme_Demo_Headset-01.analog-stereo"), true);
eq("names that differ only by case or by a mark are told apart", [Member.key("alsa_output.Abc") !== Member.key("alsa_output.abc"), Member.key("alsa_output.a-b") !== Member.key("alsa_output.a_b"), Member.key("alsa_output.a.b") !== Member.key("alsa_output.a+b")], [true, true, true]);
eq("names with nothing readable still give a key", [/^w_[0-9a-f]{16}$/.test(Member.key("alsa_output.---")), Member.key("alsa_output.-") !== Member.key("alsa_output.--")], [true, true]);
eq("a wired key never looks like a Bluetooth one", /^([0-9A-F]{2}_){5}[0-9A-F]{2}$/.test(keys[0]), false);

// A thousand made-up names: no two of them share a key
const many = new Set();
for (let i = 0; i < 1000; i++)
    many.add(Member.key("alsa_output.usb-Acme_Demo-" + i + ".analog-stereo"));
eq("a thousand names, a thousand keys", many.size, 1000);

done();
