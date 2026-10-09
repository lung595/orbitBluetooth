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
