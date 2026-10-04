.pragma library

// Pure logic of "pause when the headset comes off" (no QML, tested with gjs):
// what the wearing sensor's reading means, when a helper session has to stay
// open for it, which media players play on the headset, and which of them may
// start again. The QML in this folder only wires these to Quickshell.

// The headset's wearing status byte (anc/protocols/sony_extras.py). Only the
// two ends decide anything: the codes in between (one ear, unknown) are not
// documented well enough to act on, so they leave the last known state alone.
var WORN = 0;
var REMOVED = 4;

// "worn", "removed", or "" for a reading that decides nothing
function classify(status) {
    if (status === WORN)
        return "worn";
    return status === REMOVED ? "removed" : "";
}

// One reading against the last decided state: what to do about it, and the
// state to keep. The first decided reading is only a reference (a headset
// already off the head at start-up must never pause anything); after that,
// only a real change acts.
function step(last, status) {
    var now = classify(status);
    if (!now || now === last)
        return { "last": last, "action": "" };
    if (!last)
        return { "last": now, "action": "" };
    return { "last": now, "action": now === "removed" ? "pause" : "resume" };
}

// Only Sony headsets speak the wearing protocol: nothing is invented for the
// other brands (docs/GUIDE.md says so)
function eligible(enabled, family) {
    return !!enabled && family === "sony";
}

// Whether the helper's session has to stay open for the sensor. Nothing is
// known about a headset before its first session, so one short probe is
// allowed; it ends as soon as the headset's features show it cannot report
// wearing. After an error stay quiet: no retry loop.
function sessionWanted(enabled, family, snapshot) {
    if (!eligible(enabled, family))
        return false;
    if (!snapshot)
        return true;
    if (snapshot.status === "error")
        return false;
    if (snapshot.status !== "ready")
        return true;
    return !!(snapshot.features && snapshot.features.wear);
}

// The headsets (addresses, sorted) whose wearing is being followed. A sorted
// list lets the caller notice that nothing changed between two snapshots.
function followed(enabled, snapshots) {
    if (!enabled)
        return [];
    return Object.keys(snapshots || {}).filter(function (address) {
        var s = snapshots[address];
        return !!(s && s.features && s.features.wear);
    }).sort();
}

// --- Which players play on the headset ----------------------------------

// Letters and digits only, lower case: "Google Chrome", "google-chrome" and
// "googlechrome" are one name
function token(text) {
    return String(text || "").toLowerCase().replace(/[^a-z0-9]/g, "");
}

var MPRIS_PREFIX = "org.mpris.MediaPlayer2.";

// "org.mpris.MediaPlayer2.firefox.instance_1_42" -> "firefox"
function busName(dbusName) {
    var name = String(dbusName || "");
    if (name.indexOf(MPRIS_PREFIX) === 0)
        name = name.slice(MPRIS_PREFIX.length);
    return name.replace(/\.instance.*$/, "");
}

// The names a media player goes by (an MprisPlayer, or any object with the
// same three fields)
function playerKeys(player) {
    return [player.desktopEntry, busName(player.dbusName), player.identity].map(token).filter(Boolean);
}

// PipeWire properties of a playback stream that name the application behind it
var STREAM_PROPS = ["application.name", "application.process.binary", "application.id", "pipewire.access.portal.app_id"];

function streamKeys(properties) {
    var props = properties || {};
    return STREAM_PROPS.map(function (key) {
        return token(props[key]);
    }).filter(Boolean);
}

// Strict on purpose: a player is matched to a stream only when one of its
// names equals one of the stream's. Pausing the wrong player would be worse
// than not pausing, and nothing is guessed from "the only player".
function sameApp(playerNames, streamNames) {
    return playerNames.some(function (name) {
        return streamNames.indexOf(name) >= 0;
    });
}

// The players to pause: playing, able to pause, and fed to the headset.
// `apps` holds one list of names per stream linked to the headset.
function pausable(players, apps) {
    return (players || []).filter(function (p) {
        if (!p.isPlaying || !p.canPause)
            return false;
        var mine = playerKeys(p);
        return (apps || []).some(function (names) {
            return sameApp(mine, names);
        });
    });
}

// Of the players Orbit paused, those that may start again: still there (the
// very same object, not a new instance under the same name), still paused
// (anyone who played, stopped or changed it meanwhile is left alone) and able
// to play. `live` is the current list, `paused` the host's "Paused" value.
function resumable(held, live, paused) {
    return (held || []).filter(function (p) {
        return (live || []).indexOf(p) >= 0 && p.playbackState === paused && p.canPlay;
    });
}

// --- What `wearStatus` tells -------------------------------------------

// State of the feature for one headset, for the IPC command and for tests:
// "off" (setting), "waiting" (no answer yet), "error", "unsupported" (the
// headset does not report wearing), then "worn", "removed" or "unclear"
// (a code that decides nothing, kept as `code`)
function report(enabled, family, snapshot, holding) {
    if (!enabled)
        return { "state": "off" };
    if (family !== "sony")
        return { "state": "unsupported" };
    if (!snapshot || snapshot.status === "connecting")
        return { "state": "waiting" };
    if (snapshot.status === "error")
        return { "state": "error" };
    if (!snapshot.features || !snapshot.features.wear)
        return { "state": "unsupported" };
    var code = snapshot.state && typeof snapshot.state.wearing === "number" ? snapshot.state.wearing : null;
    return { "state": code === null ? "waiting" : classify(code) || "unclear", "code": code, "holding": holding || 0 };
}
