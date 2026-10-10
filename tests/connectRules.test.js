// Connection rules (ConnectRules.js): what runs, in which order, when a device connects.
// Run from the plugin root: gjs tests/connectRules.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const R = load("ConnectRules.js", ["STORM_MS"]);
const ADDR = "AA:BB:CC:DD:EE:01";
const SALT = "s3cret";
const key = R.keyOf(ADDR, SALT);
const full = { "volume": true, "noiseModes": ["nc", "ambient", "off"] };
const run = (rule, device, state, now) => R.onConnected(state || R.newState(), key, rule, device, now || 1000);

// Key: stable, salted, no address inside
eq("key shape", /^[0-9a-f]{16}$/.test(key), true);
eq("key stable", R.keyOf(ADDR, SALT), key);
eq("key ignores case and separator", R.keyOf("aa_bb_cc_dd_ee_01", SALT), key);
eq("key depends on salt", R.keyOf(ADDR, "other") !== key, true);
eq("key hides the address", key.indexOf("AA") < 0 && key.indexOf(":") < 0, true);
eq("key of garbage", ["", "nope", null, undefined, 42, "AA:BB:CC:DD:EE"].map(a => R.keyOf(a, SALT)), ["", "", "", "", "", ""]);

// No rule = no action
eq("no rule", run(undefined, full).actions, []);
eq("null rule", run(null, full).actions, []);
eq("empty rule", run({}, full).actions, []);
eq("unknown device (no key)", R.onConnected(R.newState(), "", { volume: 30 }, full, 1).actions, []);

// Each rule alone, then all together, volume first
eq("volume alone", run({ volume: 35 }, full).actions, [{ kind: "volume", value: 35 }]);
eq("noise alone", run({ noise: "nc" }, full).actions, [{ kind: "noise", mode: "nc" }]);
eq("both, in order", run({ noise: "ambient", volume: 20 }, full).actions,
    [{ kind: "volume", value: 20 }, { kind: "noise", mode: "ambient" }]);
eq("volume 0 is a real value", run({ volume: 0 }, full).actions, [{ kind: "volume", value: 0 }]);

// Volume capped and rounded
eq("cap high", run({ volume: 250 }, full).actions[0].value, 100);
eq("cap low", run({ volume: -5 }, full).actions[0].value, 0);
eq("rounded", run({ volume: 33.6 }, full).actions[0].value, 34);

// Invalid stored values are ignored with a reason, the valid part still runs
const bad = run({ volume: "loud", noise: "Bad Mode!" }, full);
eq("invalid: no action", bad.actions, []);
eq("invalid: reasons", bad.skipped, [{ kind: "volume", reason: "invalid" }, { kind: "noise", reason: "invalid" }]);
eq("invalid volume, good noise", run({ volume: NaN, noise: "off" }, full).actions, [{ kind: "noise", mode: "off" }]);
eq("rule not an object", run("30", full).skipped, [{ kind: "rule", reason: "invalid" }]);
eq("rule is an array", run([30], full).actions, []);
eq("infinity", run({ volume: Infinity }, full).skipped, [{ kind: "volume", reason: "invalid" }]);

// Unsupported actions give a reason code
eq("no noise control", run({ volume: 20, noise: "nc" }, { volume: true, noiseModes: [] }).skipped, [{ kind: "noise", reason: "unsupported" }]);
eq("mode the device lacks", run({ noise: "ambient" }, { volume: true, noiseModes: ["nc", "off"] }).skipped, [{ kind: "noise", reason: "unsupported" }]);
eq("no volume control", run({ volume: 20 }, { volume: false, noiseModes: [] }).skipped, [{ kind: "volume", reason: "unsupported" }]);
eq("device facts missing", run({ volume: 20, noise: "nc" }, null).skipped.map(s => s.reason), ["unsupported", "unsupported"]);

// Never raises a volume the user lowered; a higher user level does not block
let st = R.noteUserVolume(R.newState(), key, 10);
eq("lowered: not raised", run({ volume: 40 }, full, st).skipped, [{ kind: "volume", reason: "user-lowered" }]);
eq("lowered: noise still runs", run({ volume: 40, noise: "nc" }, full, st).actions, [{ kind: "noise", mode: "nc" }]);
st = R.noteUserVolume(R.newState(), key, 70);
eq("user above rule: rule applies", run({ volume: 40 }, full, st).actions, [{ kind: "volume", value: 40 }]);
eq("user level ignored if garbage", R.noteUserVolume(R.newState(), key, "x").userVolume, {});
eq("user level capped", R.noteUserVolume(R.newState(), key, 400).userVolume[key], 100);

// Reconnect storm: 5 reports in 2 s apply once; later one applies again
let state = R.newState(), applied = 0;
for (const t of [0, 400, 800, 1200, 1600]) {
    const r = R.onConnected(state, key, { volume: 30 }, full, t);
    state = r.state;
    applied += r.actions.length;
}
eq("storm applies once", applied, 1);
eq("storm reason", R.onConnected(state, key, { volume: 30 }, full, 1700).skipped, [{ kind: "all", reason: "storm" }]);
eq("after quiet it applies again", R.onConnected(state, key, { volume: 30 }, full, 1600 + R.STORM_MS).actions.length, 1);
const other = R.keyOf("AA:BB:CC:DD:EE:02", SALT);
eq("storm is per device", R.onConnected(state, other, { volume: 30 }, full, 1700).actions.length, 1);
eq("a device with no rule starts no window", run(undefined, full, state, 1700).state.lastAt, state.lastAt);

done();
