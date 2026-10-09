.pragma library

// What THIS plugin may say. It is the only diagnostics file that differs from
// one plugin to the next; the others are copied as they are. Every code is
// explained in docs/DEBUGGING.md (a test fails when one is missing there).
//
// A code is PREFIX-<level><number>: E error, W warning, I info, D debug.
// Errors and warnings also go to the DMS journal (console.error/warn, the only
// calls DMS keeps); info and debug stay in the memory buffer.

var LABEL = "orbit";
var PLUGIN = "OrbitBluetooth";

// Every key an event may carry, with the only values it may hold ("int",
// "bool", or a list of words). No key takes free text.
var FIELDS = {
    "action": ["connect", "disconnect", "pair", "trust", "forget", "scan", "power"],
    "reason": ["timeout", "refused", "no_adapter", "blocked", "not_found", "bad_data", "offline", "killed", "unknown"],
    "tool": ["pw_loopback", "pw_play", "cava", "wl_copy", "dms", "pactl", "python", "bluetoothctl"],
    "state": ["off", "on", "missing", "ready", "waiting", "stuck", "hidden", "visible", "ambient"],
    "surface": ["widget", "desktop", "daemon", "settings", "popup"],
    "via": ["button", "ipc", "script"],
    "code": "int",
    "count": "int",
    "ms": "int"
};

var CODES = {
    "ORB-E001": { "text": "A Bluetooth action failed", "fields": ["action", "reason"] },
    "ORB-E002": { "text": "Pairing failed", "fields": ["reason"] },
    "ORB-E003": { "text": "A helper program stopped unexpectedly", "fields": ["tool", "code"] },
    "ORB-E004": { "text": "The real device pictures lookup failed", "fields": ["reason"] },
    "ORB-E005": { "text": "Noise control (ANC) could not be changed", "fields": ["reason"] },
    "ORB-W010": { "text": "No usable Bluetooth adapter", "fields": ["state"] },
    "ORB-W011": { "text": "A helper program is missing", "fields": ["tool"] },
    "ORB-I020": { "text": "A surface was loaded", "fields": ["surface"] },
    "ORB-I021": { "text": "A surface was unloaded", "fields": ["surface"] },
    "ORB-I030": { "text": "A diagnostic report was requested", "fields": ["via"] },
    "ORB-D040": { "text": "The scene changed state", "fields": ["state", "count"] }
};

// The surfaces a report may list as active
var SURFACES = ["widget", "desktop", "daemon", "settings", "popup"];

// The settings a report may show: the ones that choose a behaviour. Anything
// that can hold a name, a path or a number of the user's own is left out.
var SETTINGS = {
    "showUnnamed": "bool",
    "showLabels": "bool",
    "maxDevices": "int",
    "offerNew": "bool",
    "offerPopup": "bool",
    "offerScan": "bool",
    "offerEvery": "int",
    "offerMinBattery": "int",
    "autoScan": "bool",
    "quickDisconnect": "bool",
    "scanSeconds": "int",
    "sounds": "bool",
    "volumeTick": "bool",
    "tickAlone": "bool",
    "tickEvery": "int",
    "shootingStars": "bool",
    "starDensity": ["low", "normal", "high"],
    "desktopAmbient": "bool",
    "togetherCentre": "bool",
    "learnHabits": "bool",
    "ancEnabled": "bool",
    "ancEngine": ["demand", "live"],
    "ancChatOff": "bool",
    "wearPause": "bool",
    "realPictures": "bool",
    "holeStyle": ["blackhole", "tesseract"],
    "separatePc": "bool",
    "popupMode": ["replace", "bar", "edge", "off"],
    "popupSize": ["compact", "medium", "large"],
    "popupScreens": ["focused", "all"],
    "scopeFps": "int",
    "scopeStyle": ["points", "rays", "waves", "none"],
    "volumeSteps": ["smart", "fixed"],
    "volumeSpeed": ["gentle", "balanced", "fast"],
    "keysOffered": "bool",
    "desktopBackdrop": "int",
    "hostGlyph": ["auto", "headphonesSlim", "headphones", "headphonesPremium", "headset", "earbudsStem", "earbudsRound", "earbudsCase", "speaker", "speakerTall", "soundbar", "mouse", "mouseErgo", "mouseGaming", "trackpad", "keyboard", "gamepad", "pen", "phone", "tablet", "watch", "watchRound", "glasses", "vr", "tv", "car", "laptop", "desktop", "bluetooth"],
    "soundVolume": "int",
    "togetherFineDelay": "int",
    "volumeStep": "int"
};

// What the plugin reports about itself at the moment of the report (counts of
// what is alive), never about its surroundings
var FACTS = {
    "devices": "int",
    "timersRunning": "int",
    "processesRunning": "int",
    "sceneVisible": "bool",
    "reduceMotion": "bool"
};
