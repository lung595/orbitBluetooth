.pragma library

// Decisions behind the "new device" pop-up, kept free of QML so they can be
// tested (tests/anc.test.js). NewDeviceWatch.qml feeds them the live state.

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
