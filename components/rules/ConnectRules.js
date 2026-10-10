.pragma library

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

// Settings key of a device: a salted hash, never the Bluetooth address itself.
// The salt is a random string Orbit keeps in its own settings, so the key cannot
// be brute-forced back to an address from a copy of the settings alone.
// Two independent 32-bit FNV-1a runs give a 16-hex-digit key. "" when unusable.
function keyOf(address, salt) {
    if (typeof address !== "string" || !/^([0-9A-Fa-f]{2}[:_-]){5}[0-9A-Fa-f]{2}$/.test(address))
        return "";
    var text = String(salt || "") + "|" + address.toUpperCase().replace(/[_-]/g, ":");
    var a = 0x811c9dc5, b = 0x01000193 ^ 0x5bd1e995;
    for (var i = 0; i < text.length; i++) {
        a = Math.imul(a ^ text.charCodeAt(i), 0x01000193) >>> 0;
        b = Math.imul(b ^ text.charCodeAt(i), 0x5bd1e995) >>> 0;
        b = (b ^ (b >>> 13)) >>> 0;
    }
    return ("00000000" + a.toString(16)).slice(-8) + ("00000000" + b.toString(16)).slice(-8);
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

// A fresh session state: when each device last connected, and the lowest volume
// the user chose for it since.
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
    // Every report restarts the window, so a storm that keeps going stays one.
    var next = { "lastAt": lastAt, "userVolume": state.userVolume };
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
    return { "state": next, "actions": actions, "skipped": skipped };
}
