.pragma library

// Which level the volume keys and `dms ipc call orbitBluetooth volume` move
// while a Listen together group plays (NAK-9): the member whose own level was
// touched last, else the group. Pure, tested in tests/target.test.js.

// The id of the member to move, or "" for the group. `touched` is the last
// member touched ("" once the group's level was); `members` the group's ids;
// `hasOwnLevel(id)` whether that member keeps a level of its own. A member
// that left, or has no level of its own (a wired output that follows the
// PC), falls back to the group so the keys never stop working.
function resolve(touched, members, hasOwnLevel) {
    if (!touched || (members || []).indexOf(touched) < 0)
        return "";
    return hasOwnLevel(touched) ? touched : "";
}

// What the keys move while a group plays (NAK-258): "follow" the level changed
// last (D379, the default), "group" always the group's, "device" always the
// member touched last, whatever the group did since.
var GROUP_KEYS = ["follow", "group", "device"];

function groupKeysOf(value) {
    return GROUP_KEYS.indexOf(value) < 0 ? GROUP_KEYS[0] : value;
}

// resolve() under the chosen `mode`. `lastMember` is the member touched last
// in this group, kept even after the group's level was touched; with none yet
// (or one that left) the keys fall back to the group, like resolve().
function resolveGroup(mode, touched, lastMember, members, hasOwnLevel) {
    switch (groupKeysOf(mode)) {
    case "group":
        return "";
    case "device":
        return resolve(lastMember, members, hasOwnLevel);
    default:
        return resolve(touched, members, hasOwnLevel);
    }
}

// --- Outside a group (NAK-196, D379) -------------------------------------------
// The keys follow the last level that changed: a device's own level (its
// address) or this PC's level (PC). Nothing touched, or a level that is gone,
// leaves the keys on the output you hear.

// The token for this PC's level; no Bluetooth address or node name is "pc"
var PC = "pc";
// How long a node that has just appeared is left alone (settled)
var SETTLE_MS = 1500;

// The level to move, or "" for the output you hear. `hasOwnLevel(address)`
// is whether that device is connected with a level of its own, `hasPcLevel`
// whether this PC's level can be moved. A device that left, or one that
// follows the PC, falls back so the keys never stop working.
function resolveAlone(touched, hasOwnLevel, hasPcLevel) {
    if (!touched)
        return "";
    if (touched === PC)
        return hasPcLevel ? PC : "";
    return hasOwnLevel(touched) ? touched : "";
}

// The device to mark: the target when it is not the output you hear. This
// PC's level is the output's own, so it is never marked.
function marked(target, heardAddress) {
    return target && target !== PC && target !== heardAddress ? target : "";
}

// --- A level changed by the headset's own buttons (NAK-174) -------------------
// A headset with absolute volume reports its buttons to PipeWire, which moves
// the node's volume with nobody asking Orbit. The same node also moves when
// Orbit or the PC keys write it, so every write is remembered for a moment
// and a change that matches one is an echo, not the headset.

// How long a write may take to come back, and how close the read-back must
// be: a headset keeps about 127 steps, so a level returns up to 1/127 off.
var ECHO_MS = 500;
var ECHO_GAP = 0.02;

// The writes in `book` (key -> [{ v, at }]) plus a level written to `key`
// now; entries older than ECHO_MS are dropped so the book stays tiny.
function expect(book, key, level, now) {
    const next = {};
    for (const k in (book || {})) {
        const fresh = book[k].filter(e => now - e.at <= ECHO_MS);
        if (fresh.length)
            next[k] = fresh;
    }
    next[key] = (next[key] || []).concat([{ "v": level, "at": now }]);
    return next;
}

// Whether the level read from `key` is the one a recent write asked for
function isEcho(book, key, level, now) {
    return ((book || {})[key] || []).some(e => now - e.at <= ECHO_MS && Math.abs(e.v - level) <= ECHO_GAP);
}

// Whether the headset moved its own level: `seen` is the level last read
// (null before the first read, which is a starting point, not a change)
function fromHeadset(book, key, seen, level, now) {
    if (typeof seen !== "number" || isNaN(seen) || Math.abs(level - seen) < 0.001)
        return false;
    return !isEcho(book, key, level, now);
}

// Whether a node has been read for `settleMs` already. A device that has just
// connected reports its level on its own (and WirePlumber restores one):
// outside a group that is not the user choosing it, so the first moments only
// refresh the starting point (NAK-196).
function settled(readyAt, now, settleMs) {
    return now - readyAt >= (settleMs || 0);
}
