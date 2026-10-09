// The right-click menu's entries (MenuEntries.js): short for a member of a group, as it always was elsewhere.
// Run from the plugin root: gjs tests/menuEntries.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Menu = load("MenuEntries.js", ["list", "isTogether", "ruled"]);

const ids = f => Menu.list(f).map(e => e.id);
const labels = f => Menu.list(f).map(e => e.label);

// A connected Bluetooth device with the facts the QML would gather; `extra` overrides
const bt = extra => Object.assign({ "device": true, "wired": false, "phase": "connected", "connected": true, "modes": [], "mode": "", "member": false, "groupEntry": "", "paired": true, "confirmForget": false }, extra);
const wired = extra => Object.assign({ "device": false, "wired": true, "phase": "connected", "connected": true, "modes": [], "mode": "", "member": true, "groupEntry": "Add a device…", "paired": false, "confirmForget": false }, extra);

// --- a Bluetooth member: leave or hide, nothing about the group as a whole -------------
const member = bt({ "member": true, "groupEntry": "Add a device…" });
eq("a member: Disconnect, Remove from group, Hide, Forget", labels(member), ["Disconnect", "Remove from group", "Hide", "Forget"]);
eq("a member's ids: the leave action keeps its id", ids(member), ["disconnect", "leave", "hide", "forget"]);
eq("a member's menu no longer adds a device nor stops the group (they are the radar's)", [ids(member).includes("group"), ids(member).includes("separate"), labels(member).some(l => /Add a device|Stop|Leave together/.test(l))], [false, false, false]);
eq("leaving is offered whatever the size of the group (with two, the group ends)", ids(bt({ "member": true })), ["disconnect", "leave", "hide", "forget"]);
eq("a headset in the group keeps its noise-control modes, between Disconnect and Remove from group", ids(bt({ "member": true, "modes": ["off", "nc", "ambient"], "mode": "nc" })), ["disconnect", "anc:nc", "anc:ambient", "anc:off", "leave", "hide", "forget"]);
eq("the current mode is the checked one", Menu.list(bt({ "member": true, "modes": ["off", "nc"], "mode": "nc" })).filter(e => e.checked).map(e => e.id), ["anc:nc"]);

// --- a wired member: it can only leave (and stays plugged in); hiding it would only explain ------------------
eq("a wired member: Disconnect, no Hide", labels(wired()), ["Disconnect"]);
eq("a wired output outside a group (no member) can still be hidden", ids(wired({ "member": false, "groupEntry": "" })), ["leave", "hide"]);
eq("its Disconnect is the leave action, with the unlink icon", Menu.list(wired())[0], { "id": "leave", "icon": "link_off", "label": "Disconnect", "rule": false });
eq("nothing for a Bluetooth device: no connect, mode, forget, group or stop", ids(wired({ "paired": false })).filter(i => i !== "leave"), []);

// --- a device outside the group keeps its menu -------------------------------------------
eq("outside a group: Disconnect, the group entry, Hide, Forget", labels(bt({ "groupEntry": "Create a group…" })), ["Disconnect", "Create a group…", "Hide", "Forget"]);
eq("when a group listens the entry says it adds to it", labels(bt({ "groupEntry": "Add to the group…" }))[1], "Add to the group…");
eq("no sound, no group entry", ids(bt({ "groupEntry": "" })), ["disconnect", "hide", "forget"]);
eq("not connected: Connect", ids(bt({ "connected": false })), ["connect", "hide", "forget"]);
eq("being connected: Cancel", ids(bt({ "connected": false, "phase": "connecting" })), ["cancel", "hide", "forget"]);
eq("unpaired: nothing to forget", ids(bt({ "paired": false })), ["disconnect", "hide"]);
eq("Forget asks for a second click", Menu.list(bt({ "confirmForget": true })).pop(), { "id": "forget", "icon": "delete_forever", "label": "Click to forget", "danger": true, "rule": false });

// --- the hairlines ------------------------------------------------------------------------
const rules = f => Menu.list(f).filter(e => e.rule).map(e => e.id);
eq("none before the first entry, one before the first mode, one before the group's entries", rules(bt({ "member": true, "modes": ["off", "nc", "ambient"] })), ["anc:nc", "leave"]);
eq("Hide sits under a hairline unless it follows the group's entries", [rules(bt()), rules(member)], [["hide"], ["leave"]]);
eq("outside a group the group entry has its own hairline, Hide follows it", rules(bt({ "groupEntry": "Create a group…" })), ["group"]);
eq("a wired member has no hairline", rules(wired()), []);
eq("the group's entries are the group entry and the leave one", ["group", "leave", "hide", "disconnect", "anc:nc"].map(Menu.isTogether), [true, true, false, false, false]);

done();
