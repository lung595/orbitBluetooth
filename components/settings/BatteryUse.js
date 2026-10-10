.pragma library

// What a setting costs the battery, worded once: the pill under a setting reads
// its level and its reason from here. Only settings with a real cost are listed
// (nothing decorative); each reason says what runs and when, or names the
// measurement behind the level. Same three levels as Abyss's settings.
var LEVELS = {
    "high": "High battery use",
    "medium": "Some battery use",
    "low": "Light on battery"
};

var USES = {
    "offerScan": { level: "medium", why: "Radio scan of a few seconds, repeated while it is on" },
    "offerEvery": { level: "medium", why: "The shorter the wait, the more scans" },
    "scanSeconds": { level: "medium", why: "The radio stays on for the whole scan" },
    "ancEngine": { level: "medium", why: "Always connected keeps a link open to the headset" },
    "scopeFps": { level: "low", why: "Only while the pop-up shows; Smooth draws twice as often" },
    "desktopAmbient": { level: "medium", why: "Keeps moving while uncovered; frozen when hidden" }
};

// The pill of the setting `key`: { level, label, why }, or null if it has none
function use(key) {
    var u = USES[key];
    return u ? { level: u.level, label: LEVELS[u.level], why: u.why } : null;
}
