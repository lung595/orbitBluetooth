// The ghost group (D298): which outputs the scene proposes to listen together, the key a refusal
// is remembered by, the refusals themselves, and when the plugged outputs are read again.
// Run from the plugin root: gjs tests/ghost.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Ghost = load("Ghost.js");
const Habits = load("Habits.js");
const Together = load("Together.js");

// Made-up outputs: a headset, a receiver, a keyboard with no sound, a headset in call mode, one that is
// not connected, three speakers; and four wired outputs (an interface, a dongle, a headset, a screen)
const XM = "AA:BB:CC:DD:EE:01", AV = "AA:BB:CC:DD:EE:02", KB = "AA:BB:CC:DD:EE:03", CALL = "AA:BB:CC:DD:EE:04";
const OFF = "AA:BB:CC:DD:EE:05", SP1 = "AA:BB:CC:DD:EE:06", SP2 = "AA:BB:CC:DD:EE:07", SP3 = "AA:BB:CC:DD:EE:08";
const IFACE = "alsa_output.usb-Acme_Studio-00.analog-stereo", DAC = "alsa_output.usb-Acme_Dongle-00.analog-stereo";
const PULSE = "alsa_output.usb-Acme_Pulse-00.analog-stereo", HDMI = "alsa_output.pci-0000_01_00.1.hdmi-stereo";
const GONE = "alsa_output.usb-Acme_Unplugged-00.analog-stereo";
const sinkOf = a => "bluez_output." + a.replace(/:/g, "_") + ".1";
const speaker = a => ({ "connected": true, "sink": sinkOf(a), "profile": "a2dp-sink" });
const wired = n => ({ "connected": true, "sink": n, "profile": "" });
const devices = {
    [XM]: speaker(XM), [AV]: speaker(AV), [SP1]: speaker(SP1), [SP2]: speaker(SP2), [SP3]: speaker(SP3),
    [KB]: { "connected": true, "sink": "", "profile": "" },
    [CALL]: { "connected": true, "sink": sinkOf(CALL), "profile": "headset-head-unit" },
    [OFF]: { "connected": false, "sink": "", "profile": "" },
    [IFACE]: wired(IFACE), [DAC]: wired(DAC), [PULSE]: wired(PULSE), [HDMI]: wired(HDMI)
};
// The session's own rules (Together.refusal), so that what is proposed is what a click can start
const check = list => Together.refusal(list, a => devices[a] || null);
const DAY = 20000;
const propose = (output, bluetooth, wiredOnes, extra) => Ghost.proposal(Object.assign({ "output": output, "bluetooth": bluetooth, "wired": wiredOnes, "day": DAY }, extra || {}), check);
const members = (output, bluetooth, wiredOnes, extra) => (propose(output, bluetooth, wiredOnes, extra) || {}).members || null;
// A memory that has seen these groups used `n` times, the last use on day `day` (D299)
const learn = (...groups) => groups.reduce((h, [list, n, day]) => {
    for (let i = 0; i < n; i++)
        h = Habits.record(h, list, (day || DAY) * Habits.DAY_MS);
    return h;
}, {});

// --- The sound goes to a wired output, Bluetooth devices are connected ------------------------
eq("a wired output in use and a headset connected: the group is proposed, the output in use first", members(IFACE, [XM], []), [IFACE, XM]);
eq("with two, a pair only: the first in a fixed order", members(IFACE, [AV, XM], []), [IFACE, XM]);
eq("the wired outputs plugged in make no difference then", members(IFACE, [XM], [DAC, PULSE]), [IFACE, XM]);
eq("a wired output with no Bluetooth device: nothing to propose", [members(IFACE, [], []), members(IFACE, [], [DAC, PULSE])], [null, null]);

// --- The sound goes to Bluetooth, a wired output is plugged in (the other way round) -------------
eq("a Bluetooth device in use and a wired output plugged in: proposed, the output in use first", members(XM, [XM], [IFACE]), [XM, IFACE]);
eq("with two, a pair only: the first in a fixed order", members(XM, [XM], [PULSE, DAC]), [XM, DAC]);
eq("the other Bluetooth devices make no difference then", members(XM, [XM, AV, SP1], [IFACE]), [XM, IFACE]);
eq("a Bluetooth device with no wired output plugged in: nothing to propose", [members(XM, [XM], []), members(XM, [XM, AV], [])], [null, null]);

// --- Only the other kind --------------------------------------------------------------------------
eq("two Bluetooth devices are not a ghost: dragging one onto the other is how that starts", members(XM, [AV, SP1], []), null);
eq("two wired outputs are not either", members(IFACE, [], [DAC, PULSE]), null);
eq("a wired output slipped into the Bluetooth list is not taken for a device", members(IFACE, [DAC], []), null);
eq("nor a device into the wired list", members(XM, [], [AV]), null);
eq("mixed up lists keep only the right kind", members(IFACE, [DAC, XM, "not an output"], []), [IFACE, XM]);

// --- How many, and which (without a memory: a pair, never the whole lot) ---------------------------------
eq("a pair only: the output in use and the first candidate", members(IFACE, [SP3, SP2, SP1, AV, XM], []), [IFACE, XM]);
eq("the same the other way round (names in alphabetical order)", members(XM, [], [IFACE, PULSE, DAC, HDMI]), [XM, HDMI]);
eq("exactly two, however many candidates", members(IFACE, [XM, AV, SP1], []).length, 2);
eq("one candidate twice is one", members(IFACE, [XM, XM, XM], []), [IFACE, XM]);
eq("the order the state comes in does not change the proposal", [propose(IFACE, [SP3, XM, AV, SP2, SP1], []), propose(IFACE, [SP1, SP2, AV, XM, SP3], [])].map(p => p.key), [propose(IFACE, [XM, AV, SP1, SP2, SP3], []).key, propose(IFACE, [XM, AV, SP1, SP2, SP3], []).key]);
eq("the whole proposal is the same, members and key", propose(XM, [], [IFACE, DAC, PULSE]), propose(XM, [], [PULSE, IFACE, DAC]));

// --- The group the user listens to most (D299) -----------------------------------------------------------------
const habit = learn([[IFACE, AV, SP1], 3]);
eq("a learned group that is all there is proposed whole, the output in use first", members(IFACE, [SP1, XM, AV], [], { "habits": habit }), [IFACE, AV, SP1]);
eq("from the other side too: the Bluetooth device in use first, the wired outputs after it", members(AV, [AV, SP1], [IFACE], { "habits": habit }), [AV, SP1, IFACE]);
eq("counter-proof: the same facts without the memory give the pair", members(IFACE, [SP1, XM, AV], []), [IFACE, XM]);
eq("a member of it is not there: no whole group, the pair with its best partner", members(IFACE, [XM, AV], [], { "habits": habit }), [IFACE, AV]);
eq("the output in use is not in the learned group: it is not proposed", members(XM, [XM, AV, SP1], [IFACE], { "habits": habit }), [XM, IFACE]);
eq("the best score wins: more uses", members(IFACE, [XM, AV, SP1], [], { "habits": learn([[IFACE, AV], 2], [[IFACE, XM, SP1], 5]) }), [IFACE, XM, SP1]);
eq("and an old habit weighs less than a recent one", members(IFACE, [XM, AV, SP1], [], { "habits": learn([[IFACE, XM, SP1], 5, DAY - 90], [[IFACE, AV], 2, DAY]) }), [IFACE, AV]);
eq("two groups that both fit: the better one, not the bigger one", members(IFACE, [XM, AV, SP1], [], { "habits": learn([[IFACE, XM], 4], [[IFACE, XM, AV, SP1], 1]) }), [IFACE, XM]);
eq("a learned group of one kind is proposed too (two Bluetooth devices)", members(XM, [XM, AV], [], { "habits": learn([[XM, AV], 2]) }), [XM, AV]);
eq("the pair takes the most used partner, not the first", members(IFACE, [XM, AV, SP1], [], { "habits": learn([[IFACE, SP1, DAC], 3]) }), [IFACE, SP1]);
eq("a partner learned with another output is no better than the others", members(IFACE, [XM, AV], [], { "habits": learn([[DAC, AV], 3]) }), [IFACE, XM]);
eq("the order the memory comes in does not change the group", propose(IFACE, [XM, AV, SP1], [], { "habits": learn([[IFACE, SP1, AV], 2]) }), propose(IFACE, [SP1, AV, XM], [], { "habits": learn([[AV, IFACE, SP1], 2]) }));
eq("the group's key is the same as for the refusal", propose(IFACE, [AV, SP1], [], { "habits": habit }).key, Ghost.key([IFACE, AV, SP1]));
eq("the session refuses a member of the learned group: the next one is tried", members(IFACE, [CALL, AV, XM], [], { "habits": learn([[IFACE, CALL, AV], 5], [[IFACE, XM], 1]) }), [IFACE, XM]);
eq("a learned group the user turned down gives way to the next one", members(IFACE, [XM, AV, SP1], [], { "habits": learn([[IFACE, AV, SP1], 5], [[IFACE, XM], 1]), "declined": Ghost.withDeclined({}, Ghost.key([IFACE, AV, SP1])) }), [IFACE, XM]);
eq("a memory that is not one is ignored", [null, undefined, "x", 7, [], { "x": 1 }, { "aaaaaaaa,bbbbbbbb": { "n": -1, "d": 1 } }].map(h => members(IFACE, [XM, AV], [], { "habits": h })), Array(7).fill([IFACE, XM]));

// --- What the user hid (D299) ------------------------------------------------------------------------------------------
eq("a hidden Bluetooth device is not proposed", members(IFACE, [XM, AV], [], { "hidden": { [XM]: "XM6" } }), [IFACE, AV]);
eq("a hidden wired output is not proposed", members(XM, [XM], [DAC, IFACE], { "hidden": { [DAC]: "Dongle" } }), [XM, IFACE]);
eq("nothing but hidden ones: no ghost", [members(IFACE, [XM], [], { "hidden": { [XM]: "XM6" } }), members(XM, [XM], [DAC], { "hidden": { [DAC]: "Dongle" } })], [null, null]);
eq("the output in use hidden: no ghost, whatever the rest", members(IFACE, [XM], [], { "hidden": { [IFACE]: "Studio" } }), null);
eq("a learned group with a hidden member is not proposed", members(IFACE, [AV, SP1], [], { "habits": habit, "hidden": { [SP1]: "Speaker" } }), [IFACE, AV]);
eq("counter-proof: not hidden, the learned group is", members(IFACE, [AV, SP1], [], { "habits": habit, "hidden": { [XM]: "XM6" } }), [IFACE, AV, SP1]);
eq("a store that is not one hides nothing", [null, undefined, "x", 3, []].map(h => members(IFACE, [XM], [], { "hidden": h })), Array(5).fill([IFACE, XM]));

// --- What the session would refuse is left out (so a click does what the ghost shows) ------------------
eq("a headset in call mode is not proposed", members(IFACE, [CALL], []), null);
eq("nor one that is not connected, nor one that has no sound output", [members(IFACE, [OFF], []), members(IFACE, [KB], [])], [null, null]);
eq("the first one the session accepts is the partner", members(IFACE, [KB, CALL, OFF, SP1, SP2, SP3, AV], []), [IFACE, AV]);
eq("a wired output that is gone is not proposed", members(XM, [XM], [GONE]), null);
eq("the usable one among the gone", members(XM, [XM], [GONE, DAC]), [XM, DAC]);
eq("the output in use itself refused (a headset in call mode): no ghost", members(CALL, [CALL], [IFACE]), null);
eq("the output in use gone: no ghost", members(GONE, [XM], []), null);
const asked = [];
Ghost.proposal({ "output": IFACE, "bluetooth": [AV, SP1], "wired": [] }, list => (asked.push(list), null));
eq("the session is asked about the pair, and only until one is accepted", asked, [[IFACE, AV]]);
eq("a pair the session refuses is not proposed, the next is", Ghost.proposal({ "output": IFACE, "bluetooth": [AV, SP1], "wired": [] }, list => list[1] === AV ? { "why": "no-audio", "address": AV } : null).members, [IFACE, SP1]);

// --- Anything else gives nothing -------------------------------------------------------------------------
eq("no output in use", [members("", [XM], [IFACE]), members(null, [XM], [IFACE]), members(undefined, [XM], [IFACE])], [null, null, null]);
eq("an output in use that is neither", [members("bluez_output.AA_BB.1", [XM], [IFACE]), members("not an output", [XM], [IFACE]), members(42, [XM], [IFACE])], [null, null, null]);
eq("no facts, or facts that are not an object", [Ghost.proposal(null, check), Ghost.proposal(undefined, check), Ghost.proposal("x", check), Ghost.proposal(7, check), Ghost.proposal([], check)], [null, null, null, null, null]);
eq("lists that are not lists", [members(IFACE, null, null), members(IFACE, "AA:BB:CC:DD:EE:01", []), members(XM, undefined, 5), members(XM, {}, {})], [null, null, null, null]);
eq("a list with things that are not outputs in it", members(IFACE, [null, 3, {}, "", "<script>", XM], []), [IFACE, XM]);
eq("no way to ask the session: nothing is proposed", [Ghost.proposal({ "output": IFACE, "bluetooth": [XM], "wired": [] }, null), Ghost.proposal({ "output": IFACE, "bluetooth": [XM], "wired": [] }, "yes")], [null, null]);

// --- The key a refusal is remembered by -----------------------------------------------------------------------
eq("the key is the set of members", Ghost.key([IFACE, XM]), [IFACE, XM].sort().join(","));
eq("whatever their order", Ghost.key([XM, IFACE]), Ghost.key([IFACE, XM]));
eq("another set is another key", [Ghost.key([IFACE, XM]) !== Ghost.key([IFACE, AV]), Ghost.key([IFACE, XM]) !== Ghost.key([IFACE, XM, AV]), Ghost.key([IFACE, XM]) !== Ghost.key([DAC, XM])], [true, true, true]);
eq("the proposal carries it", propose(IFACE, [AV, XM], []).key, Ghost.key([XM, IFACE]));
eq("the same group from either side is one key (the Bluetooth device in use, or the wired one)", propose(XM, [XM], [IFACE]).key, propose(IFACE, [XM], []).key);
eq("what is not a member is left out, and nothing is no key", [Ghost.key([IFACE, "x", null, XM]), Ghost.key([]), Ghost.key(null), Ghost.key("AA:BB:CC:DD:EE:01")], [Ghost.key([IFACE, XM]), "", "", ""]);

// --- The refusals ------------------------------------------------------------------------------------------------------
const k1 = Ghost.key([IFACE, XM]), k2 = Ghost.key([IFACE, AV]);
eq("nothing is refused at first", [Ghost.isDeclined({}, k1), Ghost.isDeclined(null, k1), Ghost.isDeclined(undefined, k1)], [false, false, false]);
const one = Ghost.withDeclined({}, k1);
eq("a refusal is remembered, and only that group's", [Ghost.isDeclined(one, k1), Ghost.isDeclined(one, k2)], [true, false]);
eq("the set that was given is not changed", (Ghost.withDeclined(one, k2), Object.keys(one)), [k1]);
eq("refusing twice is once", Object.keys(Ghost.withDeclined(one, k1)), [k1]);
eq("two groups, both remembered", (s => [Ghost.isDeclined(s, k1), Ghost.isDeclined(s, k2)])(Ghost.withDeclined(one, k2)), [true, true]);
eq("not a key: ignored", [null, undefined, "", 7, {}, ["x"], "x".repeat(Together.MAX_LIST_LENGTH + 1)].map(v => Object.keys(Ghost.withDeclined(one, v))), Array(7).fill([k1]));
eq("not even a set to start from", [Object.keys(Ghost.withDeclined(null, k1)), Object.keys(Ghost.withDeclined("x", k1)), Ghost.isDeclined(one, "")], [[k1], [k1], false]);
// The memory is bounded: the oldest refusals go first
let many = {};
for (let i = 0; i < Ghost.MAX_DECLINED + 10; i++)
    many = Ghost.withDeclined(many, "alsa_output.test_" + i + ",AA:BB:CC:DD:EE:01");
eq("past the bound the oldest are forgotten", [Object.keys(many).length, Ghost.isDeclined(many, "alsa_output.test_0,AA:BB:CC:DD:EE:01"), Ghost.isDeclined(many, "alsa_output.test_" + (Ghost.MAX_DECLINED + 9) + ",AA:BB:CC:DD:EE:01")], [Ghost.MAX_DECLINED, false, true]);
const renewed = Ghost.withDeclined(many, "alsa_output.test_10,AA:BB:CC:DD:EE:01");
eq("refusing an old group again makes it the newest", Object.keys(renewed).pop(), "alsa_output.test_10,AA:BB:CC:DD:EE:01");

// --- When to read the plugged outputs again -----------------------------------------------------------------------------
const node = (name, extra) => Object.assign({ "name": name, "isSink": true, "isStream": false }, extra || {});
const graph = [node(IFACE), node(sinkOf(XM)), node("alsa_input.usb-Acme_Studio-00.analog-stereo", { "isSink": false }), node(DAC), node("alsa_output.app_stream", { "isStream": true }), null, node(undefined), node("orbit_pc_AA_BB_CC_DD_EE_01")];
eq("the wired sinks of the graph, sorted: never a stream, an input, a Bluetooth or a virtual node", Ghost.wiredSinks(graph), [DAC, IFACE]);
eq("an empty or odd graph", [Ghost.wiredSinks([]), Ghost.wiredSinks(null), Ghost.wiredSinks(undefined), Ghost.wiredSinks("x"), Ghost.wiredSinks({})], [[], [], [], [], []]);
const sig = (output, bt, nodes) => Ghost.signature(output, bt, nodes);
eq("the same state, the same text, whatever the order", sig(XM, [AV, XM], graph), sig(XM, [XM, AV], graph.slice().reverse()));
eq("a wired output plugged in changes it", sig(XM, [XM], graph) !== sig(XM, [XM], graph.concat([node(PULSE)])), true);
eq("and one pulled out", sig(XM, [XM], graph) !== sig(XM, [XM], graph.filter(n => !n || n.name !== DAC)), true);
eq("the output in use changing changes it", sig(XM, [XM], graph) !== sig(IFACE, [XM], graph), true);
eq("a device connecting changes it", sig(XM, [XM], graph) !== sig(XM, [XM, AV], graph), true);
eq("a stream coming and going does not (no reading for it)", sig(XM, [XM], graph) === sig(XM, [XM], graph.concat([node("alsa_output.player", { "isStream": true })])), true);
eq("nothing known is still a text", [sig(null, null, null), sig(undefined, "x", 3)], ["||", "||"]);

done();
