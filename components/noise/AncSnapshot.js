.pragma library

// Pure snapshot bookkeeping for noise control (no QML, testable with gjs):
// how a helper report or a local command updates what the UI shows.

// Settings the UI must not see rewound by a report that predates them
var SETTINGS = ["mode", "ambient", "voice", "chat"];

// Merges one JSON line from the helper into the previous snapshot.
// `pending` is true while a command waits for the next session. Returns
// null for a line that is not JSON.
function merge(prev, line, pending, now) {
    var msg;
    try {
        msg = JSON.parse(line);
    } catch (e) {
        return null;
    }
    prev = prev || {};
    var next = Object.assign({}, prev, msg, {
        "live": msg.status !== "error",
        "at": now      // freshness of battery/charging readings
    });
    // Some headsets cannot report every mode when asked (the XM6 reads
    // "noise cancelling" and "off" alike): an unknown mode keeps the
    // last one we set or were notified of.
    if (msg.state && msg.state.mode === null && prev.state && prev.state.mode)
        next.state = Object.assign({}, msg.state, {
            "mode": prev.state.mode
        });
    // A command waiting for the next session: the closing one has not
    // seen it, so its settings are stale and must not undo what the UI
    // already shows (the mode would flash back, e.g. Silence -> Off ->
    // Silence). Its battery readings are still fresh.
    if (pending && msg.state && prev.state) {
        var kept = {};
        SETTINGS.forEach(function (k) {
            kept[k] = prev.state[k];
        });
        next.state = Object.assign({}, msg.state, kept);
    }
    return next;
}

// Optimistic update so the UI answers instantly; the helper confirms.
// Returns the snapshot with `key` set to the command's `value` text, or
// null when there is no state to update yet.
function withSetting(snapshot, key, value) {
    if (!snapshot || !snapshot.state)
        return null;
    var st = Object.assign({}, snapshot.state);
    st[key] = key === "ambient" ? parseInt(value) : (key === "voice" || key === "chat") ? value === "on" : value;
    return Object.assign({}, snapshot, {
        "state": st
    });
}

// Copy-on-write update of an address-keyed map: QML only notices a changed
// property when the whole object is replaced. A null value removes the key.
function put(map, key, value) {
    var next = Object.assign({}, map);
    if (value === null)
        delete next[key];
    else
        next[key] = value;
    return next;
}
