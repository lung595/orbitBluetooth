.pragma library

// The words that start a launcher phrase ("deco xm6 30"). They are not fixed:
// the user picks them (D424), so they live in ONE table, action -> list of
// words, read from the plugin settings key `launcherWords`. Pure logic, tested
// by tests/launcherWords.test.js.

// The only action for now; the table is shaped to take more
var ACTIONS = ["disconnect"];
var DEFAULTS = {
    "disconnect": ["deco", "off", "disconnect"]
};
var MAX_WORDS = 8;
var MAX_LENGTH = 24;

// Words that read as the delay's unit: a word equal to one would be taken for
// the delay, never for the action
var UNITS = ["m", "mn", "min", "mins", "minute", "minutes", "h", "hr", "hrs", "hour", "hours", "heure", "heures"];

// One word as it is compared and stored: trimmed and lowercased
function clean(word) {
    return String(word === undefined || word === null ? "" : word).trim().toLowerCase();
}

// The table to use: a stored table gone wrong, or an action with an emptied
// list, gets its defaults back (never a dead launcher)
function resolve(stored) {
    const out = {};
    for (const action of ACTIONS) {
        const list = stored && Array.isArray(stored[action]) ? stored[action].map(clean).filter(w => w.length > 0) : [];
        out[action] = list.length > 0 ? Array.from(new Set(list)).slice(0, MAX_WORDS) : DEFAULTS[action].slice();
    }
    return out;
}

// { ok: true, word } or { ok: false, why } for one word of `action`:
// empty | long | space | number | unit | used | full
function check(word, action, table) {
    const w = clean(word);
    if (w.length === 0)
        return { "ok": false, "why": "empty" };
    if (Array.from(w).length > MAX_LENGTH)
        return { "ok": false, "why": "long" };
    if (/\s/.test(w))
        return { "ok": false, "why": "space" };
    if (/^\d+(?:[.,]\d+)?$/.test(w))
        return { "ok": false, "why": "number" };
    if (UNITS.indexOf(w) >= 0)
        return { "ok": false, "why": "unit" };
    // Any other action of the table, so a later action is covered without a change here
    for (const other of Object.keys(table || {})) {
        if (other !== action && Array.isArray(table[other]) && table[other].map(clean).indexOf(w) >= 0)
            return { "ok": false, "why": "used" };
    }
    return { "ok": true, "word": w };
}

// The table a comma-separated list gives for `action`: { ok, table, refused }.
// Words that pass are kept, in order, once each; every other one comes back in
// `refused` with its reason, so the caller can say why (value 10). More than
// MAX_WORDS words: the rest is refused as "full". An empty list restores the
// defaults.
function setList(table, action, csv) {
    if (ACTIONS.indexOf(action) < 0)
        return { "ok": false, "why": "action", "table": resolve(table), "refused": [] };
    const kept = [], refused = [];
    const parts = String(csv === undefined || csv === null ? "" : csv).split(",");
    const base = resolve(table);
    for (const part of parts) {
        if (clean(part).length === 0)
            continue;
        const r = check(part, action, base);
        if (!r.ok)
            refused.push({ "word": clean(part).slice(0, MAX_LENGTH), "why": r.why });
        else if (kept.indexOf(r.word) < 0) {
            if (kept.length >= MAX_WORDS)
                refused.push({ "word": r.word, "why": "full" });
            else
                kept.push(r.word);
        }
    }
    const next = Object.assign({}, base);
    next[action] = kept;
    return { "ok": true, "table": resolve(next), "refused": refused };
}
