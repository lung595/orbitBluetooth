.pragma library
.import "../common/Address.js" as Address

// Pure logic of the two volumes (AudioRoute.qml), tested in tests/*.test.js.
//
// A Bluetooth audio device has two levels Orbit keeps apart:
// - the device's own level (inside the headset or amplifier), which PipeWire
//   sets on the device's sink when the device has absolute volume (AVRCP);
// - this PC's level, what the PC sends to it. PipeWire cannot hold a
//   software level of its own on that sink (it resets it to 100 % whenever
//   the device's level moves), so this PC's level lives on a small virtual
//   sink placed in front of the device: "orbit_pc_<address>", a WirePlumber
//   smart filter run by one pw-loopback that dies with the shell (D259).

var PREFIX = "orbit_pc_";

function virtualName(address) {
    const key = Address.key(address);
    return key ? PREFIX + key : "";
}

function isVirtual(name) {
    return typeof name === "string" && name.indexOf(PREFIX) === 0;
}

// "orbit_pc_AA_BB_CC_DD_EE_FF" -> "AA:BB:CC:DD:EE:FF"
function addressOfVirtual(name) {
    return isVirtual(name) ? Address.colon(name.slice(PREFIX.length)) : "";
}

// A Bluetooth device's own output sink is named bluez_output.AA_BB_CC_DD_EE_FF.1:
// its address in key form ("AA_BB_CC_DD_EE_FF"), or "" for any other sink
function sinkKey(name) {
    const m = /^bluez_output\.([^.:]+)(\.[0-9]+)?$/.exec(typeof name === "string" ? name : "");
    return m ? Address.key(m[1]) : "";
}

function isDeviceSink(name) {
    return sinkKey(name) !== "";
}

function addressOfSink(name) {
    return Address.colon(sinkKey(name));
}

// The device's sink among PipeWire's nodes (never Orbit's virtual one)
function deviceSink(nodes, address) {
    const key = Address.key(address);
    if (!key || !nodes)
        return null;
    for (let i = 0; i < nodes.length; i++) {
        const n = nodes[i];
        if (n && n.isSink && !n.isStream && sinkKey(n.name) === key)
            return n;
    }
    return null;
}

function virtualSink(nodes, address) {
    const name = virtualName(address);
    if (!name || !nodes)
        return null;
    for (let i = 0; i < nodes.length; i++) {
        const n = nodes[i];
        if (n && n.isSink && !n.isStream && n.name === name)
            return n;
    }
    return null;
}

// What DMS's output list shows for the virtual sink. Only letters, digits,
// spaces and a few marks of the device's name survive: the text goes into
// a module argument, never into a shell (value 11).
function description(deviceName) {
    const clean = String(deviceName || "").replace(/[^\p{L}\p{N} ()+._-]/gu, "").replace(/\s+/g, " ").trim().slice(0, 48);
    return (clean || "Bluetooth") + " (Orbit)";
}

// The one way Orbit runs a pw-loopback (the PC-level filter below, Listen
// together): bash watches its standard input (a pipe from the shell) and
// stops pw-loopback the moment the shell goes away, even after a crash, so
// nothing outlives the shell (value 12). Data only as "$1", "$2" and "$3"
// (value 11): the capture and playback properties, and an optional delay in
// seconds.
const LOOPBACK_SCRIPT = '{ cat >/dev/null; kill "$$" 2>/dev/null; } <&0 & exec pw-loopback ${3:+-d "$3"} --capture-props="$1" --playback-props="$2" </dev/null';

// Nothing is remembered by WirePlumber for the two ends Orbit creates
const FORGET = " state.restore-props=false state.restore-target=false";

function loopbackArgs(capture, playback, delaySeconds) {
    const args = ["bash", "-c", LOOPBACK_SCRIPT, "orbit", capture + FORGET, playback + FORGET];
    if (delaySeconds)
        args.push(String(delaySeconds));
    return args;
}

// The PC-level filter: a WirePlumber smart filter, a virtual sink that
// WirePlumber itself slips between every app and the device. The default
// output stays the device, so nothing in WirePlumber's saved state changes,
// and the filter lives exactly as long as the process (above).
// Returns an argv list, or null if anything does not check out.
function filterArgs(address, master, deviceName) {
    const name = virtualName(address);
    if (!name || !isDeviceSink(master))
        return null;
    const capture = "media.class=Audio/Sink node.name=" + name + " node.description=\"" + description(deviceName) + "\"" + " filter.smart=true filter.smart.name=" + name + " filter.smart.target={ node.name = \"" + master + "\" }";
    const playback = "node.name=" + name + ".out node.passive=true";
    return loopbackArgs(capture, playback);
}

// Clicking the planet: with one Bluetooth audio device connected, this PC
// goes quiet (the device keeps its level for later); with several (two
// headsets on one film), only that device does.
function muteTarget(audioDevices) {
    return audioDevices > 1 ? "device" : "pc";
}

// The level asked by `dms ipc call orbitBluetooth deviceVolume|pcVolume <arg>`:
// "up", "down", "+10", "-5", "40" or "40%". Steps of 5 %, capped to 0..1.
// Returns -1 for anything else (value 11: checked and capped).
function ipcLevel(arg, current) {
    const a = String(arg === undefined || arg === null ? "" : arg).trim().toLowerCase();
    if (a.length === 0 || a.length > 5)
        return -1;
    const now = Math.max(0, Math.min(1, Number(current) || 0));
    const snap = v => Math.max(0, Math.min(1, Math.round(v * 100) / 100));
    if (a === "up")
        return snap(Math.round(now * 20 + 1) / 20);
    if (a === "down")
        return snap(Math.round(now * 20 - 1) / 20);
    const m = /^([+-]?)([0-9]{1,3})%?$/.exec(a);
    if (!m)
        return -1;
    const n = parseInt(m[2], 10) / 100;
    if (m[1] === "+")
        return snap(now + n);
    if (m[1] === "-")
        return snap(now - n);
    return n > 1 ? -1 : snap(n);
}

// Absolute volume (AVRCP): BlueZ gives the device's audio transport a
// "Volume" property only when the device takes its level from the PC.
// `busctl tree --list org.bluez` lists object paths; the transport is
// "<device path>/sepN/fdM".
function transportPath(tree, devicePath) {
    if (!Address.isDevicePath(devicePath))
        return "";
    const lines = String(tree || "").split("\n");
    for (let i = 0; i < lines.length; i++) {
        const p = lines[i].trim();
        if (p.indexOf(devicePath + "/") === 0 && /^\/sep[0-9]+\/fd[0-9]+$/.test(p.slice(devicePath.length)))
            return p;
    }
    return "";
}

// `busctl --json=short get-property ... Volume` -> 0..127, or -1
function transportVolume(json) {
    try {
        const v = JSON.parse(json);
        return v && v.type === "q" && v.data >= 0 && v.data <= 127 ? v.data : -1;
    } catch (e) {
        return -1;
    }
}

// The Material Symbols icon at the foot of the device's half circle, from
// Orbit's device kind (DeviceCatalog.resolve)
function iconFor(kind) {
    const k = String(kind || "");
    if (/^earbuds/.test(k))
        return "earbuds";
    if (/^headphones|^headset/.test(k))
        return "headphones";
    if (k === "tv")
        return "tv";
    if (k === "car")
        return "directions_car";
    return "speaker";
}

// Pop-up sizes (D258): width x height of the horizontal pop-up
function popupSize(size) {
    if (size === "compact")
        return { "w": 300, "h": 172 };
    if (size === "large")
        return { "w": 540, "h": 300 };
    return { "w": 420, "h": 236 };
}

// How the pop-up sits (D258): "replace" takes the place of DMS's volume OSD
// (DMS's own position; upright when DMS shows its OSDs on a side), "bar"
// unfolds under Orbit's bar widget, "edge" stands on the right screen edge.
// Upright, the half circles turn a quarter: their flat side against the
// screen edge, so they open toward the screen.
function popupLayout(mode, osdOnSide, osdOnLeft, size) {
    const s = popupSize(size);
    const upright = mode === "edge" || (mode === "replace" && !!osdOnSide);
    const rotation = upright ? (mode === "replace" && osdOnLeft ? 90 : -90) : 0;
    return upright ? { "w": s.h, "h": s.w, "upright": true, "rotation": rotation } : { "w": s.w, "h": s.h, "upright": false, "rotation": 0 };
}

// Which levels the pop-up shows, from the nodes AudioRoute gives
// (deviceNode, pcNode). Both: two half circles. Only one level (a device
// with no level of its own, "Separate PC volume" off, or an output that is
// not Bluetooth): that one alone, as the "pc" half. "ownIcon" tells the
// lone half is the device's own level, so its foot shows the device.
function shownLevels(deviceNode, pcNode) {
    if (deviceNode && pcNode)
        return { "device": deviceNode, "pc": pcNode, "ownIcon": false };
    return { "device": null, "pc": pcNode || deviceNode || null, "ownIcon": !pcNode && !!deviceNode };
}
