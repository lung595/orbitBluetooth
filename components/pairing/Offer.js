.pragma library

// Decisions behind the "new device" pop-up, kept free of QML so they can be
// tested (tests/*.test.js). NewDeviceWatch.qml feeds them the live state.

// Why the background scan must not run right now, or "" when it may.
// ctx: {enabled, btOn, asleep, busy, audioConnected, onBattery, level, minLevel}
//   busy: discovery already running (a view scans, or another app)
//   level: the machine's battery in %, -1 without a battery
function scanBlocker(ctx) {
    if (!ctx.enabled)
        return "off";
    if (!ctx.btOn)
        return "bluetooth off";
    // Nobody would see the pop-up, and the radio would work for nothing
    if (ctx.asleep)
        return "screen locked or off";
    if (ctx.busy)
        return "already scanning";
    // Discovery shares the radio with the audio link: on many adapters it
    // makes music stutter for the length of the scan, every minute
    if (ctx.audioConnected)
        return "audio device connected";
    if (ctx.onBattery && ctx.level >= 0 && ctx.level < ctx.minLevel)
        return "battery below " + ctx.minLevel + "%";
    return "";
}

// Is this device worth a pop-up? Only named, unpaired, unconnected audio
// devices: a headset in pairing mode, not the neighbours' phones and TVs.
// d: {address, name, paired, connected}, family: DeviceCatalog family
function isCandidate(d, family, ignored) {
    if (!d || !d.address || d.paired || d.connected)
        return false;
    if (family !== "audio")
        return false;
    if (ignored && ignored[d.address] !== undefined)
        return false;
    const n = (d.name || "").trim();
    return n.length > 0 && !/^([0-9a-f]{2}[:\-_]){5}[0-9a-f]{2}$/i.test(n);
}

// After "Later" (or no answer) a device in pairing mode is offered again at
// most this often, so a headset left discoverable does not nag every minute
var snoozeMs = 10 * 60 * 1000;

function offerable(address, snoozed, now) {
    const until = snoozed[address];
    return until === undefined || now >= until;
}

// Word shown above the name: "New headphones nearby"
function headline(kind) {
    if (/^earbuds/.test(kind))
        return "New earbuds nearby";
    if (/^speaker|soundbar/.test(kind))
        return "New speaker nearby";
    if (kind === "headset")
        return "New headset nearby";
    return "New headphones nearby";
}

// Brand names for the sheet's subtitle, by noise-control family (Anc.js)
var BRANDS = {
    "sony": "Sony", "apple": "Apple", "samsung": "Samsung", "bose": "Bose", "nothing": "Nothing",
    "soundcore": "Soundcore", "huawei": "Huawei", "oppo": "OPPO", "xiaomi": "Xiaomi",
    "earfun": "EarFun", "moondrop": "Moondrop", "haylou": "Haylou", "onemore": "1MORE"
};

// "What you get" tiles of the pairing sheet, at most three, all known
// locally before anything is paired.
// info: {family (Anc.js, "" if none), hours (rated, 0 if unknown), kind}
function features(info) {
    const out = [];
    if (info.family)
        out.push({ "icon": "noise_control_on", "value": "Noise control", "label": "Supported" });
    if (info.hours > 0)
        out.push({ "icon": "battery_full", "value": "≈ " + info.hours + " h", "label": "Battery life" });
    if (/^earbuds/.test(info.kind))
        out.push({ "icon": "earbuds", "value": "Case & buds", "label": "Each battery" });
    out.push({ "icon": "volume_up", "value": "Volume", "label": "Per device" });
    // Mains-powered things (soundbar, smart speaker, TV...) have nothing to charge
    if (!/^(soundbar|speakerTall|tv|desktop|car)$/.test(info.kind))
        out.push({ "icon": "bolt", "value": "Charging", "label": "Time to full" });
    return out.slice(0, 3);
}

// A failed pairing in plain words. BlueZ errors arrive as text such as
// "org.bluez.Error.AuthenticationRejected" or "Page Timeout".
function errorText(error) {
    const e = String(error || "");
    if (/AuthenticationRejected|AuthenticationCanceled|Rejected|Canceled/i.test(e))
        return "The pairing was declined.";
    if (/AuthenticationFailed|PIN|passkey/i.test(e))
        return "The code did not match. Try again.";
    if (/Timeout|timed out|Page/i.test(e))
        return "No answer. Is it still in pairing mode?";
    if (/InProgress|Busy/i.test(e))
        return "Busy with another pairing. Try again.";
    if (/NotReady|powered|NotAvailable/i.test(e))
        return "Bluetooth is not ready. Try again.";
    if (/AlreadyExists/i.test(e))
        return "Already paired: connecting from Orbit should work.";
    return "Could not connect. Is it still in pairing mode?";
}
