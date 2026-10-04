// Noise control (Anc.js): which brand a name means, and the mode order.
// Run from the plugin root: gjs tests/noise.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Anc = load("Anc.js", ["family", "nextMode", "ordered", "chatEndsIndex", "CHAT_ENDS"]);

// Brand detection by Bluetooth name
const names = {
    "WH-1000XM6": "sony", "WF-1000XM5": "sony", "LinkBuds S": "sony",
    "AirPods Pro": "apple", "Beats Studio Pro": "apple",
    "Nothing Ear (2)": "nothing", "CMF Buds Pro 2": "nothing",
    "Galaxy Buds2 Pro (A1B2)": "samsung", "Buds3 Pro": "samsung",
    "Bose QC35 II": "bose", "Bose QC Ultra Headphones": "bose",
    "Soundcore Life Q30": "soundcore", "Soundcore Space Q45": "soundcore",
    "HUAWEI FreeBuds Pro 3": "huawei", "HONOR Earbuds 2 Lite": "huawei", "HUAWEI FreeLace Pro": "huawei",
    "realme Buds Air6 Pro": "oppo", "OPPO Enco Air2": "oppo", "OnePlus Buds Pro 2": "oppo",
    "Redmi Buds 5 Pro": "xiaomi", "REDMI Buds 8 Active": "xiaomi",
    "EarFun Air Pro 4": "earfun", "Space Travel 2 Ultra": "moondrop",
    "HAYLOU S35 ANC": "haylou", "1MORE SonoFlow SE": "onemore",
    // Never sent vendor commands: unknown, unsupported or no noise control
    "MX Master 3S": "", "Xbox Wireless Controller": "", "JBL Tune 770NC": "", "Jabra Elite 85t": "",
    "EarFun Free 2": "", "": ""
};
for (const n in names)
    eq("family(" + JSON.stringify(n) + ")", Anc.family(n), names[n]);

// How long a conversation lasts: the names map to the headset's values 0..3
eq("chatEnds names", Anc.CHAT_ENDS, ["short", "standard", "long", "never"]);
eq("chatEndsIndex", ["short", " Long ", "NEVER", "standard"].map(Anc.chatEndsIndex), [0, 2, 3, 1]);
eq("chatEndsIndex: not a name", ["", "2", "forever", null, undefined].map(Anc.chatEndsIndex), [-1, -1, -1, -1, -1]);

// Mode order and cycling (right-click menu, IPC ancCycle)
eq("ordered", Anc.ordered(["off", "ambient", "nc"]), ["nc", "ambient", "off"]);
eq("next skips off", Anc.nextMode(["nc", "ambient", "off"], "ambient"), "nc");
eq("next from unknown", Anc.nextMode(["nc", "ambient", "off"], null), "nc");
eq("next with only on/off", Anc.nextMode(["nc", "off"], "nc"), "off");


// Helper reports merged into the snapshot (AncSnapshot.js)
const Snap = load("AncSnapshot.js", ["merge", "withSetting", "put"]);
const prev = { state: { mode: "nc", ambient: 5, voice: false, chat: true }, battery: 1 };
const line = (o) => JSON.stringify(o);
eq("merge: not JSON", Snap.merge(prev, "oops", false, 1), null);
eq("merge: live and time", Snap.merge(null, line({ status: "ok" }), false, 7), { status: "ok", live: true, at: 7 });
eq("merge: error is not live", Snap.merge(prev, line({ status: "error" }), false, 7).live, false);
eq("merge: unknown mode keeps ours", Snap.merge(prev, line({ state: { mode: null, ambient: 9 } }), false, 1).state, { mode: "nc", ambient: 9 });
eq("merge: pending keeps settings", Snap.merge(prev, line({ state: { mode: "off", ambient: 9, voice: true, chat: false, x: 1 } }), true, 1).state, { mode: "nc", ambient: 5, voice: false, chat: true, x: 1 });
eq("merge: not pending takes report", Snap.merge(prev, line({ state: { mode: "off" } }), false, 1).state, { mode: "off" });
eq("merge: keeps other fields", Snap.merge(prev, line({ state: { mode: "off" } }), false, 1).battery, 1);

// Optimistic command echo
eq("withSetting: no state", Snap.withSetting({}, "mode", "off"), null);
eq("withSetting: mode", Snap.withSetting(prev, "mode", "off").state.mode, "off");
eq("withSetting: ambient int", Snap.withSetting(prev, "ambient", "12").state.ambient, 12);
eq("withSetting: chat bool", Snap.withSetting(prev, "chat", "off").state.chat, false);
eq("withSetting: keeps old", prev.state.mode, "nc");
eq("withSetting: how long a conversation lasts is a number", Snap.withSetting(prev, "chatEnds", "2").state.chatEnds, 2);
eq("withSetting: a bad number is not echoed", Snap.withSetting(prev, "ambient", "loud"), null);
eq("withSetting: a key with no state of its own is not echoed", Snap.withSetting(prev, "wear", "on"), null);
eq("merge: pending keeps the conversation length", Snap.merge({ state: { chatEnds: 1 } }, line({ state: { chatEnds: 3 } }), true, 1).state.chatEnds, 1);
eq("merge: pending takes a setting the old state never had", Snap.merge({ state: { mode: "nc" } }, line({ state: { mode: "off", chatEnds: 2 } }), true, 1).state, { mode: "nc", chatEnds: 2 });
eq("merge: the wearing reading is never held back", Snap.merge({ state: { wearing: 0 } }, line({ state: { wearing: 4 } }), true, 1).state.wearing, 4);

// Copy-on-write map updates
const map = { a: 1 };
eq("put: adds without touching the old map", Snap.put(map, "b", 2), { a: 1, b: 2 });
eq("put: old map unchanged", map, { a: 1 });
eq("put: null removes", Snap.put(map, "a", null), {});
eq("put: falsy values are kept", Snap.put(map, "z", 0), { a: 1, z: 0 });

done();
