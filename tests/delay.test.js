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
eq("the result is capped at the longest delay", [Delay.autoDelayMs(9000, 0, 0), Delay.autoDelayMs(499, 0, 100), Delay.autoDelayMs(500, 0, 0)], [Together.MAX_DELAY_MS, Together.MAX_DELAY_MS, Together.MAX_DELAY_MS]);
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

done();
