.pragma library

// Volume keys bound to Orbit's smart steps from the first start (D265,
// NAK-214). Orbit cannot catch the shell's own "dms ipc call audio
// increment" (its IPC target and functions belong to DMS), and DMS's keys
// move the default output, never the last device that changed, so Orbit asks
// DMS's own keybind command to point the two keys at Orbit, and "Give back"
// (or uninstalling) asks it to set them back to DMS's own action. Not `dms
// keybinds reset`: DMS's binds.kdl is itself the default, so a reset deletes
// the line and leaves the key doing nothing. Nothing is written by Orbit itself.
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
// removed), "dms ipc" answers "Target not found."; an Orbit too old for
// this command, "Function not found."; no shell, nothing. Each time the key
// falls back to DMS's own step, so the keys never stop working. Data reaches the shell
// only as positional parameters.
function action(dir, step) {
    const n = Math.max(1, Math.min(20, parseInt(step) || FALLBACK_STEP));
    return 'spawn "sh" "-c" "case \\"$(dms ipc call orbitBluetooth volume \\"$1\\")\\" in \\"\\"|Target*|Function*) exec dms ipc call audio \\"$2\\" \\"$3\\";; esac" "orbit" "' + dir + '" "' + DMS_VERB[dir] + '" "' + n + '"';
}

function setArgs(dir, step) {
    return ["dms", "keybinds", "set", PROVIDER, KEYS[dir], action(dir, step), "--allow-when-locked", "--json"];
}

// DMS's own action, written back the way DMS writes it
function dmsAction(dir, step) {
    const n = Math.max(1, Math.min(20, parseInt(step) || FALLBACK_STEP));
    return "spawn dms ipc call audio " + DMS_VERB[dir] + " " + n;
}

function backArgs(dir, step) {
    return ["dms", "keybinds", "set", PROVIDER, KEYS[dir], dmsAction(dir, step), "--allow-when-locked", "--json"];
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

// The DMS step kept at the end of Orbit's action (its fallback), to give
// the key back exactly as it was
function _orbitStep(a) {
    const m = typeof a === "string" ? a.match(/(?:increment|decrement)\W+(\d{1,2})\W*$/) : null;
    return m ? parseInt(m[1]) : FALLBACK_STEP;
}

// DMS's own default: "spawn dms ipc call audio increment 3"
function _dmsStep(a, dir) {
    const m = typeof a === "string" ? a.match(/^spawn dms ipc call audio (increment|decrement) (\d{1,2})$/) : null;
    return m && m[1] === DMS_VERB[dir] ? parseInt(m[2]) : 0;
}

// What the two volume keys do now:
// - "dms": both still DMS's default: Orbit can take them
// - "orbit": both bound to Orbit
// - "custom": the user's own shortcut on at least one: Orbit leaves them
// - "unknown": the listing could not be read
// with the DMS step to fall back on, the keys already bound to Orbit and
// the DMS step each of them goes back to
function classify(text) {
    const binds = _binds(text);
    if (!binds)
        return { "state": "unknown", "step": FALLBACK_STEP, "mine": [], "back": {} };
    const find = k => binds.find(b => b.key === k);
    const up = find(KEYS.up), down = find(KEYS.down);
    const ua = up ? up.action : "", da = down ? down.action : "";
    // The keys bound to Orbit, to give back on "Undo" even if only one is
    const mine = ["up", "down"].filter(d => isOrbit(d === "up" ? ua : da));
    const back = {};
    for (const d of mine)
        back[d] = _orbitStep(d === "up" ? ua : da);
    if (mine.length === 2)
        return { "state": "orbit", "step": back.up, "mine": mine, "back": back };
    const su = _dmsStep(ua, "up"), sd = _dmsStep(da, "down");
    if (su > 0 && sd > 0)
        return { "state": "dms", "step": su, "mine": [], "back": {} };
    return { "state": "custom", "step": FALLBACK_STEP, "mine": mine, "back": back };
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
// word to click, or null. Short, to fit beside the mute icons. "done" tells
// the user that Orbit took the keys, and how to give them back.
var NOTES = {
    "done": { "text": "Smart volume keys on", "action": "Undo" },
    "undone": { "text": "Volume keys back to DMS", "action": "" },
    "manual": { "text": "Bind your keys to Orbit", "action": "" },
    "failed": { "text": "Could not change the keys", "action": "" }
};
function note(kind) {
    return NOTES[kind] || null;
}
