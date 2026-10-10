.pragma library

// "deco xm6 30", "dans 5 min deco xm6", "in 5 min disconnect xm6": what a
// launcher phrase asks and which device it means. French and English, free
// word order. The action words come in as an argument (LauncherWords table),
// never from here. Pure logic, tested by tests/disconnectPhrase.test.js.

var MIN_MINUTES = 1;
var MAX_MINUTES = 1440;
// A phrase or a device query is never longer than this (value 11)
var MAX_PHRASE = 120;

var HOUR_UNITS = ["h", "hr", "hrs", "hour", "hours", "heure", "heures"];
var MINUTE_UNITS = ["m", "mn", "min", "mins", "minute", "minutes"];
// Little words that introduce a delay and are not part of a device name
var LEAD = ["in", "dans", "after", "apres", "pour", "for"];

// What a refusal says, one table for the launcher and the command line (value 10)
var NOTES = {
    "badDelay": "Use a whole number of minutes, 1 to 1440",
    "noDelay": "Add a delay in minutes, like 30",
    "noDevice": "Give a device name",
    "long": "That phrase is too long",
    "none": "No connected device matches that name",
    "ambiguous": "Several connected devices match, type more of the name",
    "nothing": "No disconnect is waiting for that device"
};

function note(why) {
    return NOTES[why] || NOTES.noDevice;
}

// Text from outside (a device name) as the screen may show it: no long dash,
// whatever the source (owner rule of 2026-10-10)
function plain(text) {
    return String(text === undefined || text === null ? "" : text).replace(/\s*[\u2013\u2014]\s*/g, " - ");
}

// Lowercase, accents and case folded away
function fold(text) {
    return String(text === undefined || text === null ? "" : text).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

// { text, unit } for "5", "5min", "2h"; null when the token is not a delay
function amount(token) {
    const m = /^(\d+(?:[.,]\d+)?)([a-z]*)$/.exec(token);
    if (!m || (m[2] && HOUR_UNITS.indexOf(m[2]) < 0 && MINUTE_UNITS.indexOf(m[2]) < 0))
        return null;
    return { "text": m[1], "unit": m[2] };
}

function _minutes(text, unit) {
    if (!/^\d+$/.test(text))
        return NaN;
    return Number(text) * (HOUR_UNITS.indexOf(unit) >= 0 ? 60 : 1);
}

// What a phrase asks: { ok: true, action, query, minutes } or { ok: false, why }
// why: empty | long | noWord | noDevice | noDelay | badDelay
// `words` is the action -> list of words table (already resolved)
function parse(phrase, words) {
    const text = fold(phrase).trim();
    if (text.length === 0)
        return { "ok": false, "why": "empty" };
    if (text.length > MAX_PHRASE)
        return { "ok": false, "why": "long" };
    const tokens = text.split(/\s+/);
    let action = "";
    let at = -1;
    for (let i = 0; i < tokens.length && at < 0; i++) {
        for (const a of Object.keys(words || {})) {
            if ((words[a] || []).map(fold).indexOf(tokens[i]) >= 0) {
                action = a;
                at = i;
                break;
            }
        }
    }
    if (at < 0)
        return { "ok": false, "why": "noWord" };
    const rest = tokens.filter((_, i) => i !== at);
    // A number with a unit, or after a leading word, is the delay; else the last number
    const found = [];
    rest.forEach((t, i) => {
        const a = amount(t);
        if (a)
            found.push({ "i": i, "a": a, "unit": a.unit.length > 0 });
    });
    if (found.length === 0)
        return { "ok": false, "why": "noDelay" };
    let pick = found[found.length - 1];
    for (const f of found) {
        const spaced = rest[f.i + 1] !== undefined && (HOUR_UNITS.indexOf(rest[f.i + 1]) >= 0 || MINUTE_UNITS.indexOf(rest[f.i + 1]) >= 0);
        if (f.unit || spaced || (f.i > 0 && LEAD.indexOf(rest[f.i - 1]) >= 0)) {
            pick = f;
            break;
        }
    }
    const drop = new Set([pick.i]);
    const next = rest[pick.i + 1];
    let unit = pick.a.unit;
    if (!unit && next !== undefined && (HOUR_UNITS.indexOf(next) >= 0 || MINUTE_UNITS.indexOf(next) >= 0)) {
        unit = next;
        drop.add(pick.i + 1);
    }
    if (pick.i > 0 && LEAD.indexOf(rest[pick.i - 1]) >= 0)
        drop.add(pick.i - 1);
    const query = rest.filter((_, i) => !drop.has(i)).join(" ");
    const minutes = _minutes(pick.a.text, unit);
    if (query.length === 0)
        return { "ok": false, "why": "noDevice" };
    if (!(minutes >= MIN_MINUTES && minutes <= MAX_MINUTES))
        return { "ok": false, "why": "badDelay" };
    return { "ok": true, "action": action, "query": query, "minutes": minutes };
}

// The connected devices among a Bluetooth device list, as [{ address, name }]:
// the only ones a phrase or a command may mean, there is nothing to disconnect
// on the others
function connectedOf(values) {
    const out = [];
    for (let i = 0; i < (values ? values.length : 0); i++) {
        if (values[i].connected)
            out.push({ "address": values[i].address, "name": values[i].name || "" });
    }
    return out;
}

// Which device a name fragment or a Bluetooth address means among [{ address, name }]:
// { ok: true, address } | { ok: false, why: "none" | "ambiguous" | "noDevice" }.
// An exact address wins, then an exact (folded) name, then a fragment; several
// matches are never guessed.
function findDevice(query, devices) {
    const q = fold(query).trim();
    if (q.length === 0 || q.length > MAX_PHRASE)
        return { "ok": false, "why": "noDevice" };
    const byAddress = (devices || []).filter(d => fold(d.address) === q);
    if (byAddress.length === 1)
        return { "ok": true, "address": byAddress[0].address };
    const list = (devices || []).map(d => ({ "address": d.address, "name": fold(d.name).trim() })).filter(d => d.name.length > 0);
    const exact = list.filter(d => d.name === q);
    const hits = exact.length > 0 ? exact : list.filter(d => d.name.indexOf(q) >= 0);
    if (hits.length === 0)
        return { "ok": false, "why": "none" };
    return hits.length === 1 ? { "ok": true, "address": hits[0].address } : { "ok": false, "why": "ambiguous" };
}

// A delay given on its own (IPC): whole minutes within bounds, else null
function cleanMinutes(value) {
    const s = String(value === undefined || value === null ? "" : value).trim();
    if (!/^\d{1,5}$/.test(s))
        return null;
    const n = Number(s);
    return n >= MIN_MINUTES && n <= MAX_MINUTES ? n : null;
}

// The pending delays are a plain map address -> end time (ms). These keep it
// pure: each returns a new map.
function schedule(pending, address, minutes, now) {
    const next = Object.assign({}, pending);
    next[address] = now + minutes * 60000;
    return next;
}

function cancel(pending, address) {
    const next = Object.assign({}, pending);
    delete next[address];
    return next;
}
