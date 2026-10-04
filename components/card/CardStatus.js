.pragma library
.import "Charge.js" as Charge
.import "../device/DeviceCatalog.js" as Catalog
.import "../device/Glyphs.js" as Glyphs

// The wording of the detail card, kept out of the QML so every branch can be
// tested: the kind line under the name and the three lines of the battery
// card. `body` is the focused orbiting body, `c` its charge analysis (or
// null), `level` its battery percent (-1 when unknown).

// "Headphones  ·  Connected"
function kindLine(body) {
    if (!body)
        return "";
    const state = body.connected ? "Connected" : body.paired ? "Paired" : "Available";
    return Glyphs.label(body.kind) + "  ·  " + state;
}

function statusIcon(body, c) {
    if (body?.phase === "connecting")
        return "sync";
    if (body?.charging)
        return "bolt";
    if (c && c.state === "full")
        return "battery_full";
    return body?.connected ? "bluetooth_connected" : "bluetooth";
}

// `since`: when the device connected (ms, 0 when unknown); `now`: the scene clock
function statusText(body, c, since, now) {
    if (!body)
        return "";
    if (body.phase === "connecting")
        return "Connecting...";
    if (body.phase === "disconnecting")
        return "Disconnecting...";
    if (body.charging)
        return "Charging...";
    if (c && c.state === "full")
        return "Fully charged";
    if (body.connected)
        return since > 0 ? "Connected for " + Catalog.formatDuration(now - since) : "Connected";
    return body.paired ? "Not connected" : "Available nearby";
}

// The line under the status: the level and its time, or why there is none
function detailText(body, c, level) {
    if (!body)
        return "";
    if (level >= 0)
        return Charge.levelText(level, c, body.charging ?? false);
    if (body.connected)
        return "No battery info";
    const sig = body.rawSignal;
    return sig > 0 ? "Signal " + Math.round(sig * 100) + "%" : "Out of range";
}
