.pragma library
.import "../common/Address.js" as Address
.import "../together/Member.js" as Member

// Pure engine for connection rules (no QML, testable with gjs): from a device's
// stored rule and a "connected" event it decides, in order, what Orbit does so
// that a headset never starts at 100 %: first the start volume, then the noise
// mode. Everything is applied in memory when the device connects; nothing is
// written to WirePlumber or DMS settings (D423 point 1, value 12).
//
// Left out on purpose: "make it the default output". Quickshell's
// preferredDefaultAudioSink writes to WirePlumber's state for good, so it cannot
// be done in memory only (see the P.. entry of this story).

// Same device connecting again within this window counts once: a flaky link
// reports "connected" several times in a row.
var STORM_MS = 2000;

// Reason codes the view turns into the value 10 message ("guided, never blocked").
var UNSUPPORTED = "unsupported";   // the device cannot do this action
var USER_LOWERED = "user-lowered"; // the user already set a lower volume this session
var INVALID = "invalid";           // the stored value is unusable and was ignored
var STORM = "storm";               // the same connection was already handled

// Seeds of the two halves of a key, unrelated to the ones of Member.key and
// Habits so that a stored key never matches a name elsewhere.
var SEEDS = [1540483477, 2246822519];

// Settings key of a device: 16 hex digits of two seeded hashes (Member.hash)
// over a salt and the address, so the address is not in clear in the settings.
// Not a secret: the salt sits in the same settings, so a copy of them could
// still be brute-forced. "" when the address is unusable or the salt is empty
// (an unsalted key would be the same on every machine), which means no action.
function keyOf(address, salt) {
    var mac = Address.colon(address);
    if (!mac || typeof salt !== "string" || !salt)
        return "";
    var text = salt + "|" + mac;
    return Member.hash(text, SEEDS[0]) + Member.hash(text, SEEDS[1]);
}

// Cleans a stored rule: keeps only a whole volume in 0-100 and a mode name.
// Returns { rule, invalid: [kind...] }; rule is null when nothing usable is left.
function sanitize(stored) {
    var rule = {}, invalid = [];
    if (stored === null || typeof stored !== "object" || Array.isArray(stored))
        return { "rule": null, "invalid": stored === undefined || stored === null ? [] : ["rule"] };
    if (stored.volume !== undefined && stored.volume !== null) {
        var v = typeof stored.volume === "number" ? stored.volume : NaN;
        if (isFinite(v))
            rule.volume = Math.max(0, Math.min(100, Math.round(v)));
        else
            invalid.push("volume");
    }
    if (stored.noise !== undefined && stored.noise !== null) {
        if (typeof stored.noise === "string" && /^[a-z][a-z0-9_-]{0,23}$/.test(stored.noise))
            rule.noise = stored.noise;
        else
            invalid.push("noise");
    }
    return { "rule": Object.keys(rule).length ? rule : null, "invalid": invalid };
}

// A fresh session state: when each device's rule last ran, and the latest
// volume the user chose for it since.
function newState() {
    return { "lastAt": {}, "userVolume": {} };
}

// The user moved a device's volume themselves (slider, keys, wheel).
function noteUserVolume(state, key, level) {
    if (!key || typeof level !== "number" || !isFinite(level))
        return state;
    var next = Object.assign({}, state.userVolume);
    next[key] = Math.max(0, Math.min(100, Math.round(level)));
    return { "lastAt": state.lastAt, "userVolume": next };
}

// Decides what to do when `key` connects at time `now` (ms).
// `rule`: stored rule (any shape, cleaned here). `device`: what it can do,
// { volume: bool, noiseModes: [names] }. Returns
// { state, actions: [{kind:"volume",value}|{kind:"noise",mode}] in the order to
//   run them, skipped: [{kind, reason}] }.
// No key or no usable rule = no action. The volume always comes first, so it is
// in place before any sound can reach the headset.
function onConnected(state, key, rule, device, now) {
    var none = { "state": state, "actions": [], "skipped": [] };
    if (!key)
        return none;
    var clean = sanitize(rule);
    var skipped = clean.invalid.map(function (kind) { return { "kind": kind, "reason": INVALID }; });
    if (!clean.rule)
        return { "state": state, "actions": [], "skipped": skipped };

    var last = state.lastAt[key];
    var lastAt = Object.assign({}, state.lastAt);
    lastAt[key] = now;
    var next = { "lastAt": lastAt, "userVolume": state.userVolume };
    // Every report inside a window restarts it, so a storm that keeps going stays one.
    if (last !== undefined && now - last < STORM_MS)
        return { "state": next, "actions": [], "skipped": [{ "kind": "all", "reason": STORM }] };

    var actions = [];
    device = device || {};
    if (clean.rule.volume !== undefined) {
        var lowered = state.userVolume[key];
        if (!device.volume)
            skipped.push({ "kind": "volume", "reason": UNSUPPORTED });
        else if (lowered !== undefined && lowered < clean.rule.volume)
            skipped.push({ "kind": "volume", "reason": USER_LOWERED });
        else
            actions.push({ "kind": "volume", "value": clean.rule.volume });
    }
    if (clean.rule.noise !== undefined) {
        if ((device.noiseModes || []).indexOf(clean.rule.noise) < 0)
            skipped.push({ "kind": "noise", "reason": UNSUPPORTED });
        else
            actions.push({ "kind": "noise", "mode": clean.rule.noise });
    }
    // The window opens only when something ran: Bluetooth says "connected"
    // before the audio node exists, and that first report (no facts yet, so
    // nothing applied) must not swallow the second one that has them.
    return { "state": actions.length ? next : state, "actions": actions, "skipped": skipped };
}
