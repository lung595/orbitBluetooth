.pragma library

// Volume keys bound to Orbit's smart steps, on the user's click only (D265).
// Orbit cannot catch the shell's own "dms ipc call audio increment" (its
// IPC target and functions belong to DMS), so the click asks DMS's own
// keybind command to point the two keys at Orbit, and "Undo" asks it to
// reset them to the DMS default. Nothing is written by Orbit itself.
// Pure: builds argument lists and reads `dms keybinds show niri`.

var PROVIDER = "niri";
var KEYS = {
    "up": "XF86AudioRaiseVolume",
    "down": "XF86AudioLowerVolume"
};
var DMS_VERB = {
    "up": "increment",
    "down": "decrement"
};
// The step DMS uses if Orbit is gone (its own default)
var FALLBACK_STEP = 3;

// The bound action. If Orbit is not loaded (plugin turned off, folder
// removed), "dms ipc" answers "Target not found." and the key falls back to
// DMS's own step, so the keys never stop working. Data reaches the shell
// only as positional parameters.
function action(dir, step) {
    const n = Math.max(1, Math.min(20, parseInt(step) || FALLBACK_STEP));
    return 'spawn "sh" "-c" "case \\"$(dms ipc call orbitBluetooth volume \\"$1\\")\\" in Target*) exec dms ipc call audio \\"$2\\" \\"$3\\";; esac" "orbit" "' + dir + '" "' + DMS_VERB[dir] + '" "' + n + '"';
}

function setArgs(dir, step) {
    return ["dms", "keybinds", "set", PROVIDER, KEYS[dir], action(dir, step), "--allow-when-locked", "--json"];
}

function resetArgs(dir) {
    return ["dms", "keybinds", "reset", PROVIDER, KEYS[dir], "--json"];
}

var SHOW_ARGS = ["dms", "keybinds", "show", PROVIDER];

// Every bind of the provider's listing, flattened: [{key, action, source}]
function _binds(text) {
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!data || typeof data.binds !== "object" || data.binds === null)
        return null;
    const out = [];
    for (const group of Object.keys(data.binds)) {
        const list = data.binds[group];
        if (Array.isArray(list))
            for (const b of list)
                if (b && typeof b.key === "string")
                    out.push(b);
    }
    return out;
}

function isOrbit(a) {
    return typeof a === "string" && a.indexOf("ipc call orbitBluetooth volume") >= 0;
}

// DMS's own default: "spawn dms ipc call audio increment 3"
function _dmsStep(a, dir) {
    const m = typeof a === "string" ? a.match(/^spawn dms ipc call audio (increment|decrement) (\d{1,2})$/) : null;
    return m && m[1] === DMS_VERB[dir] ? parseInt(m[2]) : 0;
}

// What the two volume keys do now:
// - "dms": both still DMS's default: Orbit can offer to take them
// - "orbit": both bound to Orbit
// - "custom": the user's own shortcut on at least one: Orbit leaves them
// - "unknown": the listing could not be read
// with the DMS step to fall back on and the keys already bound to Orbit
function classify(text) {
    const binds = _binds(text);
    if (!binds)
        return { "state": "unknown", "step": FALLBACK_STEP, "mine": [] };
    const find = k => binds.find(b => b.key === k);
    const up = find(KEYS.up), down = find(KEYS.down);
    const ua = up ? up.action : "", da = down ? down.action : "";
    // The keys bound to Orbit, to give back on "Undo" even if only one is
    const mine = ["up", "down"].filter(d => isOrbit(d === "up" ? ua : da));
    if (mine.length === 2)
        return { "state": "orbit", "step": FALLBACK_STEP, "mine": mine };
    const su = _dmsStep(ua, "up"), sd = _dmsStep(da, "down");
    if (su > 0 && sd > 0)
        return { "state": "dms", "step": su, "mine": [] };
    return { "state": "custom", "step": FALLBACK_STEP, "mine": mine };
}

// A `--json` answer of `dms keybinds set` or `reset`
function succeeded(text) {
    try {
        const r = JSON.parse(text);
        return !!r && r.success === true;
    } catch (e) {
        return false;
    }
}

// The one-line note in the volume scope (shown once, D265): text and the
// word to click, or null. Short, to fit beside the mute icons.
var NOTES = {
    "offer": { "text": "Smart volume keys?", "action": "Enable" },
    "done": { "text": "Smart volume keys on", "action": "Undo" },
    "undone": { "text": "Volume keys back to DMS", "action": "" },
    "manual": { "text": "Bind your keys to Orbit", "action": "" },
    "failed": { "text": "Could not change the keys", "action": "" }
};
function note(kind) {
    return NOTES[kind] || null;
}
