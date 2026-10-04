// The automatic delay of Listen together: only a wired copy waits, for what the Bluetooth output adds.
// Run from the plugin root: gjs tests/delay.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Delay = load("Delay.js");
const Together = load("Together.js");

// Made-up members: two Bluetooth outputs and two wired ones
const BT1 = "AA:BB:CC:DD:EE:01", BT2 = "AA:BB:CC:DD:EE:02";
const W1 = "alsa_output.usb-Acme_Demo_Headset-00.analog-stereo", W2 = "alsa_output.pci-0000_00_00.0.analog-stereo";

// --- One copy ------------------------------------------------------------------------
eq("the wired copy waits for what the source adds", Delay.autoDelayMs(180, 5, 0), 175);
eq("the fine correction is added, either way", [Delay.autoDelayMs(180, 5, 20), Delay.autoDelayMs(180, 5, -20), Delay.autoDelayMs(180, 5)], [195, 155, 175]);
eq("a source as quick as the member: nothing to wait", [Delay.autoDelayMs(5, 5, 0), Delay.autoDelayMs(5, 180, 0)], [0, 0]);
eq("the correction alone never goes below 0", [Delay.autoDelayMs(10, 5, -50), Delay.autoDelayMs(5, 180, -50)], [0, 0]);
eq("the correction can lift a zero", Delay.autoDelayMs(5, 5, 30), 30);
eq("the result is a whole number", [Delay.autoDelayMs(100.4, 0.2, 0), Delay.autoDelayMs(100.5, 0, 0), Delay.autoDelayMs(10, 0, 0.4)], [100, 101, 10]);
eq("the result is capped at the longest delay", [Delay.autoDelayMs(9000, 0, 0), Delay.autoDelayMs(950, 0, 100), Delay.autoDelayMs(1000, 0, 0)], [Together.MAX_DELAY_MS, Together.MAX_DELAY_MS, Together.MAX_DELAY_MS]);
eq("the correction itself is held within 100 ms", [Delay.autoDelayMs(200, 0, 9999), Delay.autoDelayMs(200, 0, -9999), Delay.cleanFine(9999), Delay.cleanFine(-9999), Delay.cleanFine(42)], [300, 100, 100, -100, 42]);
eq("a correction that is not a number counts for nothing", [Delay.autoDelayMs(100, 0, "x"), Delay.autoDelayMs(100, 0, NaN), Delay.autoDelayMs(100, 0, null), Delay.autoDelayMs(100, 0, Infinity), Delay.autoDelayMs(100, 0, "50")], [100, 100, 100, 100, 100]);
eq("a latency that is not known gives no delay, no figure is made up", [Delay.autoDelayMs(undefined, 5, 0), Delay.autoDelayMs(180, undefined, 0), Delay.autoDelayMs(null, null, 0), Delay.autoDelayMs(NaN, 5, 0), Delay.autoDelayMs(180, NaN, 0), Delay.autoDelayMs("180", 5, 0)], [0, 0, 0, 0, 0, 0]);
eq("a negative or infinite latency is not a latency either", [Delay.autoDelayMs(-1, 5, 0), Delay.autoDelayMs(180, -1, 0), Delay.autoDelayMs(Infinity, 5, 0), Delay.autoDelayMs(180, Infinity, 0), Delay.autoDelayMs(-Infinity, 0, 0)], [0, 0, 0, 0, 0]);
eq("an unknown latency ignores the correction too", Delay.autoDelayMs(undefined, 5, 40), 0);

// --- The copies of a plan --------------------------------------------------------------
const tap = (member, capture) => ({ "member": member, "capture": capture, "playback": "x" });
// A Bluetooth source copied to a wired output and to a second Bluetooth output
const plan = { "source": BT1, "taps": [tap(W1, "c"), tap(BT2, "c"), tap(W2, "c")] };
const latencies = { [BT1]: 200, [BT2]: 250, [W1]: 5, [W2]: 20 };

eq("only the wired copies wait, never the Bluetooth one", Delay.delaysFor(plan, latencies, 0), { [W1]: 195, [W2]: 180 });
eq("the correction applies to every wired copy", Delay.delaysFor(plan, latencies, 10), { [W1]: 205, [W2]: 190 });
eq("a Bluetooth copy is never in the answer, whatever its latency", Object.keys(Delay.delaysFor(plan, { [BT1]: 1, [BT2]: 9999, [W1]: 0, [W2]: 0 }, 0)).indexOf(BT2), -1);
eq("a wired copy with an unknown latency gets none, the others still do", Delay.delaysFor(plan, { [BT1]: 200, [W1]: 5 }, 0), { [W1]: 195 });
eq("an unknown source latency: nobody waits", Delay.delaysFor(plan, { [W1]: 5, [W2]: 20 }, 50), {});
eq("a wired copy as quick as the source is not in the answer", Delay.delaysFor(plan, { [BT1]: 5, [W1]: 5, [W2]: 20 }, 0), {});
eq("a wired source: its wired copy waits for nothing", Delay.delaysFor({ "source": W1, "taps": [tap(W2, "c"), tap(BT1, "c")] }, { [W1]: 5, [W2]: 5, [BT1]: 200 }, 0), {});
eq("a session with no wired member has no automatic delay", Delay.delaysFor({ "source": BT1, "taps": [tap(BT2, "c")] }, { [BT1]: 200, [BT2]: 10 }, 0), {});
eq("no plan, no taps, no latencies", [Delay.delaysFor(null, latencies, 0), Delay.delaysFor({ "source": "", "taps": [] }, latencies, 0), Delay.delaysFor(plan, null, 0), Delay.delaysFor(plan, {}, 0), Delay.delaysFor({ "source": BT1 }, latencies, 0), Delay.delaysFor(undefined, undefined, 0)], [{}, {}, {}, {}, {}, {}]);
eq("the delays are those the copies take", Together.commands({ "source": BT1, "taps": [{ "member": W1, "capture": "orbit_pc_AA_BB_CC_DD_EE_01", "playback": W1 }] }, Delay.delaysFor(plan, latencies, 0))[0].command[6], "0.195");

// --- The latencies the graph gives, and the delays added up ------------------------------------
const BTSINK = "bluez_output.AA_BB_CC_DD_EE_01.1";
const sinks = { [BT1]: BTSINK, [W1]: "alsa_output.usb-Acme_Demo_Headset-00.analog-stereo" };
eq("a member's latency is the one of its sink", Delay.latenciesOf(sinks, { [BTSINK]: { "latencyMs": 218.7 }, [sinks[W1]]: { "latencyMs": 21 } }), { [BT1]: 218.7, [W1]: 21 });
eq("a wired output the graph gives no time for counts as 0", Delay.latenciesOf(sinks, { [BTSINK]: { "latencyMs": 200 }, [sinks[W1]]: {} }), { [BT1]: 200, [W1]: 0 });
eq("a Bluetooth output with no figure is left out, never guessed", Delay.latenciesOf(sinks, { [BTSINK]: {}, [sinks[W1]]: { "latencyMs": 5 } }), { [W1]: 5 });
eq("nothing read yet: only the wired outputs answer, with 0", [Delay.latenciesOf(sinks, {}), Delay.latenciesOf(sinks, null), Delay.latenciesOf(sinks, undefined)], new Array(3).fill({ [W1]: 0 }));
eq("a figure that is not a latency is no figure", Delay.latenciesOf(sinks, { [BTSINK]: { "latencyMs": "200" }, [sinks[W1]]: { "latencyMs": -4 } }), { [W1]: 0 });
eq("no sinks, no latencies", [Delay.latenciesOf(null, {}), Delay.latenciesOf({}, { [BTSINK]: { "latencyMs": 5 } }), Delay.latenciesOf(undefined, undefined)], [{}, {}, {}]);
eq("the delays of a copy are the automatic one and its own", Delay.total({ [W1]: 195 }, { [W1]: 20, [BT2]: 50 }), { [W1]: 215, [BT2]: 50 });
eq("the sum is capped like any delay, and a zero is not listed", [Delay.total({ [W1]: 900 }, { [W1]: 900 }), Delay.total({ [W1]: 0 }, { [BT2]: 0 })], [{ [W1]: Together.MAX_DELAY_MS }, {}]);
eq("no delay of either kind", [Delay.total(null, null), Delay.total({}, undefined), Delay.total(undefined, { [BT2]: 40 })], [{}, {}, { [BT2]: 40 }]);

// --- A wired source waits in its filter, never the Bluetooth outputs ---------------------------
const wired = { "source": W1, "taps": [tap(BT1, "c"), tap(W2, "c"), tap(BT2, "c")] };
const heard = { [W1]: 5, [W2]: 5, [BT1]: 200, [BT2]: 250 };
eq("a Bluetooth source: no source wait, the wired copies wait as before", Delay.waitsFor(plan, latencies, 0), { "source": 0, "taps": { [W1]: 195, [W2]: 180 } });
eq("a wired source waits for the slowest Bluetooth copy", Delay.waitsFor(wired, heard, 0).source, 245);
eq("the Bluetooth copies never wait", Object.keys(Delay.waitsFor(wired, heard, 0).taps).filter(m => m === BT1 || m === BT2), []);
eq("a wired copy beside it waits as long, the source is heard that much later", Delay.waitsFor(wired, heard, 0).taps, { [W2]: 245 });
eq("the correction moves the source and the wired copy alike", [Delay.waitsFor(wired, heard, 10), Delay.waitsFor(wired, heard, -10)], [{ "source": 255, "taps": { [W2]: 255 } }, { "source": 235, "taps": { [W2]: 235 } }]);
eq("a wired copy that is slower than the source is lined up with the Bluetooth one too", Delay.waitsFor({ "source": W1, "taps": [tap(BT1, "c"), tap(W2, "c")] }, { [W1]: 5, [W2]: 40, [BT1]: 200 }, 0), { "source": 195, "taps": { [W2]: 160 } });
eq("a Bluetooth copy faster than the wired source: nothing waits", Delay.waitsFor({ "source": W1, "taps": [tap(BT1, "c")] }, { [W1]: 30, [BT1]: 10 }, 0), { "source": 0, "taps": {} });
eq("a negative correction never makes the wait negative", Delay.waitsFor({ "source": W1, "taps": [tap(BT1, "c")] }, { [W1]: 5, [BT1]: 20 }, -100).source, 0);
eq("a correction alone lifts a zero on the source when a Bluetooth copy is there", Delay.waitsFor({ "source": W1, "taps": [tap(BT1, "c")] }, { [W1]: 30, [BT1]: 10 }, 15).source, 15);
eq("only wired copies: the correction moves them and the source stays", Delay.waitsFor({ "source": W1, "taps": [tap(W2, "c")] }, { [W1]: 5, [W2]: 5 }, 20), { "source": 0, "taps": { [W2]: 20 } });
eq("an unknown Bluetooth latency: the source does not wait", Delay.waitsFor(wired, { [W1]: 5, [W2]: 5 }, 30), { "source": 0, "taps": { [W2]: 30 } });
eq("an unknown source latency: nothing waits", Delay.waitsFor(wired, { [W2]: 5, [BT1]: 200, [BT2]: 250 }, 30), { "source": 0, "taps": {} });
eq("the wait is capped like every other", Delay.waitsFor({ "source": W1, "taps": [tap(BT1, "c")] }, { [W1]: 0, [BT1]: 9000 }, 0).source, Together.MAX_DELAY_MS);
eq("no plan, no taps, no latencies", [Delay.waitsFor(null, heard, 0), Delay.waitsFor({ "source": W1 }, heard, 0), Delay.waitsFor(wired, null, 0), Delay.waitsFor(undefined, undefined, 0)], new Array(4).fill({ "source": 0, "taps": {} }));
eq("the waits are those the processes take", Together.commands({ "source": W1, "taps": [{ "member": BT1, "capture": "orbit_wired_w_x", "playback": "bluez_output.AA_BB_CC_DD_EE_01.1" }] }, {}, Delay.waitsFor(wired, heard, 0).source)[0].command[6], "0.245");

done();
