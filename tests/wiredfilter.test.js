// The delay filter of a wired source (Listen together): its name, its command, and the copies that read it.
// Run from the plugin root: gjs tests/wiredfilter.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Route = load("Route.js");
const Together = load("Together.js");
const Member = load("Member.js");

// Made-up outputs: two wired ones and a Bluetooth headset
const W1 = "alsa_output.usb-Acme_Demo_Headset-00.analog-stereo", W2 = "alsa_output.usb-Acme_Studio_Interface_0000-00.HiFi__Line__sink";
const BT = "AA:BB:CC:DD:EE:01";
const btSink = "bluez_output.AA_BB_CC_DD_EE_01.1";

// --- The filter's name ------------------------------------------------------------------
const name = Route.wiredFilterName(W1);
eq("the name is Orbit's prefix and the member's key", name, "orbit_wired_" + Member.key(W1));
eq("the name has nothing that splits a property string", /^orbit_wired_w_[a-z0-9_]+$/.test(name), true);
eq("two outputs, two names", Route.wiredFilterName(W1) !== Route.wiredFilterName(W2), true);
eq("only a wired output has one", [Route.wiredFilterName(btSink), Route.wiredFilterName(BT), Route.wiredFilterName("alsa_output.x; y"), Route.wiredFilterName(""), Route.wiredFilterName(null)], ["", "", "", "", ""]);
eq("the name is recognised, and nothing else is", [Route.isWiredFilter(name), Route.isWiredFilter("orbit_pc_AA_BB_CC_DD_EE_01"), Route.isWiredFilter(W1), Route.isWiredFilter(name + " x"), Route.isWiredFilter(name + "\""), Route.isWiredFilter("orbit_wired_w_" + "a".repeat(80)), Route.isWiredFilter(5)], [true, false, false, false, false, false, false]);

// --- The filter's command -----------------------------------------------------------------
const cmd = Route.wiredFilterArgs(W1, "0.195");
eq("bash watches stdin, data only as positional parameters", [cmd.slice(0, 2), cmd[3], cmd.length], [["bash", "-c"], "orbit", 7]);
eq("the script has no data in it", /usb|alsa|orbit_wired|0\.195/.test(cmd[2]), false);
eq("the wait is the third parameter, in seconds", cmd[6], "0.195");
eq("a smart filter in front of that output", [/filter\.smart=true/.test(cmd[4]), cmd[4].indexOf("filter.smart.target={ node.name = \"" + W1 + "\" }") > 0, cmd[4].indexOf("node.name=" + name + " ") >= 0, /media\.class=Audio\/Sink/.test(cmd[4])], [true, true, true, true]);
eq("the playback never falls back to another output", [/node\.dont-fallback=true/.test(cmd[5]), /node\.passive=true/.test(cmd[5])], [true, true]);
eq("nothing is remembered by WirePlumber", [/state\.restore-props=false state\.restore-target=false$/.test(cmd[4]), /state\.restore-props=false state\.restore-target=false$/.test(cmd[5])], [true, true]);
eq("no default-sink change, no module", /default|load-module/.test(cmd.join(" ")), false);
eq("DMS's list shows a generic name, never the output's", /node\.description="Wired output \(Orbit\)"/.test(cmd[4]), true);
eq("a label is cleaned like the PC-level filter's", /description="Studio \(Orbit\)"/.test(Route.wiredFilterArgs(W1, "0.100", "Stu\"dio")[4]), true);
eq("the longest wait is accepted, one more is not", [Route.wiredFilterArgs(W1, "1.000") !== null, Route.wiredFilterArgs(W1, "1.001"), Route.wiredFilterArgs(W1, "2")], [true, null, null]);
eq("no wait, or a wait that is not seconds written by delayArg: no command", [Route.wiredFilterArgs(W1, ""), Route.wiredFilterArgs(W1, "0"), Route.wiredFilterArgs(W1, "0.000"), Route.wiredFilterArgs(W1, "-0.1"), Route.wiredFilterArgs(W1, "abc"), Route.wiredFilterArgs(W1, "0.1; reboot"), Route.wiredFilterArgs(W1, "0.1234"), Route.wiredFilterArgs(W1, "--help"), Route.wiredFilterArgs(W1, null), Route.wiredFilterArgs(W1, undefined), Route.wiredFilterArgs(W1, NaN)], new Array(11).fill(null));
eq("not a wired output's name: no command", [Route.wiredFilterArgs(btSink, "0.1"), Route.wiredFilterArgs("alsa_output.x\"y", "0.1"), Route.wiredFilterArgs("alsa_output.a b", "0.1"), Route.wiredFilterArgs("alsa_output.a..b", "0.1"), Route.wiredFilterArgs("alsa_output.", "0.1"), Route.wiredFilterArgs("", "0.1"), Route.wiredFilterArgs(null, "0.1")], new Array(7).fill(null));
eq("the sink name is the only data in the properties, and it is quote-safe", cmd.slice(4).every(s => !/["'{},;$`\\]/.test(s.replace(/filter\.smart\.target=\{ node\.name = "[^"]*" \}/, "").replace(/node\.description="[^"]*"/, ""))), true);

// --- The copies read the filter ---------------------------------------------------------------
eq("one wait for every pw-loopback Orbit runs", [Route.MAX_DELAY_MS, Together.MAX_DELAY_MS], [1000, 1000]);
const tap = { "member": BT, "capture": name, "playback": btSink };
const copy = Together.args(tap, 0);
eq("a copy may read the filter's monitor", [copy !== null, copy && copy[4].indexOf("target.object=" + name + " ") >= 0, copy && /stream\.capture\.sink=true/.test(copy[4])], [true, true, true]);
eq("a name that only looks like the filter is no source", [Together.args({ ...tap, "capture": name + " node.dont-fallback=false" }), Together.args({ ...tap, "capture": "orbit_wired_x y" }), Together.args({ ...tap, "capture": "orbit_wired_\"" })], [null, null, null]);

// The plan of a wired source: its filter is `pc` once it exists, else the copy reads the sink
const sound = pcOfW1 => a => a === W1 ? { "sink": W1, "pc": pcOfW1, "profile": "" } : a === BT ? { "sink": btSink, "pc": "", "profile": "a2dp-sink" } : null;
eq("a wired source with a filter: the copy reads the filter's monitor", Together.plan([W1, BT], sound(name), W1).taps, [{ "member": BT, "capture": name, "playback": btSink }]);
eq("before the filter exists: the copy reads the sink", Together.plan([W1, BT], sound(""), W1).taps, [{ "member": BT, "capture": W1, "playback": btSink }]);

// The processes of a session: the filter first, then the copies
const plan = Together.plan([W1, BT], sound(name), W1);
const all = Together.commands(plan, {}, 195);
eq("the filter comes first, under a key no member has, then the copy", [all.map(c => c.key), Member.clean(Together.FILTER_KEY)], [[Together.FILTER_KEY, BT], ""]);
eq("the filter's command is the one Route gives, with the wait in seconds", [all[0].command, all.length], [Route.wiredFilterArgs(W1, "0.195"), 2]);
eq("the copy has no wait of its own", all[1].command.length, 6);
eq("no wait, no filter", [Together.commands(plan, {}, 0).map(c => c.key), Together.commands(plan, {}).map(c => c.key), Together.commands(plan, {}, -5).map(c => c.key)], [[BT], [BT], [BT]]);
eq("a Bluetooth source never has a filter", Together.commands(Together.plan([BT, W1], a => a === BT ? { "sink": btSink, "pc": "", "profile": "" } : { "sink": W1, "pc": "", "profile": "" }, btSink), {}, 195).map(c => c.key), [W1]);
eq("a wait longer than the longest is capped", Together.commands(plan, {}, 99999)[0].command[6], "1.000");
eq("no plan: no filter", Together.commands(null, {}, 195), []);
const running = {};
all.forEach(c => { running[c.key] = c.command; });
eq("the same wait changes nothing", Together.diff(running, Together.commands(plan, {}, 195)), { "stop": [], "start": [] });
const longer = Together.diff(running, Together.commands(plan, {}, 210));
eq("a new wait restarts the filter only", [longer.stop, longer.start.map(w => w.key)], [[Together.FILTER_KEY], [Together.FILTER_KEY]]);
eq("no wait needed any more: the filter stops, the copy goes on", [Together.diff(running, Together.commands(plan, {}, 0)).stop, Together.diff(running, Together.commands(plan, {}, 0)).start], [[Together.FILTER_KEY], []]);

done();
