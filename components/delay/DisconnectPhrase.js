.pragma library

// Disconnect after a delay (`dms ipc call orbitBluetooth disconnectIn`): which
// connected device a name or an address means, the delay in minutes, and the
// pending delays. Pure logic, tested by tests/disconnectPhrase.test.js.

var MIN_MINUTES = 1;
var MAX_MINUTES = 1440;
// A phrase or a device query is never longer than this (value 11)
var MAX_PHRASE = 120;

// What a refusal says on the command line (value 10)
var NOTES = {
    "badDelay": "Use a whole number of minutes, 1 to 1440",
    "noDevice": "Give a device name",
    "none": "No connected device matches that name",
    "ambiguous": "Several connected devices match, type more of the name",
    "nothing": "No disconnect is waiting for that device"
};

function note(why) {
    return NOTES[why] || NOTES.noDevice;
}

// Lowercase, accents and case folded away
function fold(text) {
    return String(text === undefined || text === null ? "" : text).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

// The connected devices among a Bluetooth device list, as [{ address, name }]:
// the only ones a command may mean, there is nothing to disconnect
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
