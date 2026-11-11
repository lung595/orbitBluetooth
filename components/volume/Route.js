.pragma library
.import "../common/Address.js" as Address
.import "../together/Member.js" as Member

// Pure logic of the two volumes (AudioRoute.qml), tested in tests/*.test.js.
//
// A Bluetooth audio device has two levels Orbit keeps apart:
// - the device's own level (inside the headset or amplifier), which PipeWire
//   sets on the device's sink when the device has absolute volume (AVRCP);
// - this PC's level, what the PC sends to it. PipeWire cannot hold a
//   software level of its own on that sink (it resets it to 100 % whenever
//   the device's level moves), so this PC's level lives on a small virtual
//   sink placed in front of the device: "orbit_pc_<address>", a WirePlumber
//   smart filter run by one loopback process (pipewire -c, below) that dies
//   with the shell (D259).

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

// The sink node called `name` among PipeWire's nodes (never a stream), or null
function sinkNamed(nodes, name) {
    if (!name || !nodes)
        return null;
    for (let i = 0; i < nodes.length; i++) {
        const n = nodes[i];
        if (n && n.isSink && !n.isStream && n.name === name)
            return n;
    }
    return null;
}

// Where a tick for `node` must play: { name, bypass }. The PC-level filter is
// left out, the tick plays in the device sink behind it (bypass): Listen
// together copies read the filter's monitor, so a tick played through it
// would be heard in every copy and not in the member that changed alone.
// Any other node plays as it is.
function tickOutput(nodes, node) {
    const name = node ? node.name : "";
    const device = isVirtual(name) ? deviceSink(nodes, addressOfVirtual(name)) : null;
    return device ? { "name": device.name, "bypass": true } : { "name": name, "bypass": false };
}

function virtualSink(nodes, address) {
    return sinkNamed(nodes, virtualName(address));
}

// What DMS's output list shows for the virtual sink. Only letters, digits,
// spaces and a few marks of the device's name survive: the text goes into
// a module argument, never into a shell (value 11).
function description(deviceName, fallback) {
    const clean = String(deviceName || "").replace(/[^\p{L}\p{N} ()+._-]/gu, "").replace(/\s+/g, " ").trim().slice(0, 48);
    return (clean || fallback || "Bluetooth") + " (Orbit)";
}

// The one way Orbit runs a loopback (the PC-level filter below, the wired
// filter, Listen together): the stock `pipewire` binary run as a client with a
// config that loads libpipewire-module-loopback in its own process, the way
// pw-loopback does, so pipewire-utils is not needed (it is not on a default
// install). pipewire only reads a config whose name ends in ".conf" and reads
// a pipe as empty, so the config lives in an unlinked file of $XDG_RUNTIME_DIR
// (tmpfs, 0700) held open on fd 3 and is reached through
// "$XDG_RUNTIME_DIR/orbit-loopback.conf" -> /dev/fd/3, a link that holds no
// data and is the same for every loopback (made atomically: link + rename).
// The file is unlinked before anything is written to it, so no name on disk
// ever holds data. An absolute config path also means no drop-in directory is
// read, so it runs the same everywhere. With no absolute $XDG_RUNTIME_DIR it
// exits 1 at once (bash's own error there is 127, which reads as "pipewire is
// not installed"). The config:
// - log.level 0: nothing about the devices goes to stderr (and the journal);
// - application.name: mixers show "Orbit", not "pipewire";
// - module-rt first, as PipeWire's own client.conf has it: the audio thread
//   gets realtime priority when the system allows it, and nothing fails when
//   it does not.
// Data only as "$1", "$2" and "$3" (value 11): each is written as ONE quoted
// SPA-JSON string (backslashes and quotes escaped), so it cannot close the
// string and add modules. bash watches its standard input (a pipe from the
// shell) and stops pipewire the moment the shell goes away, even after a
// crash, so nothing outlives the shell (value 12). Unlike pw-loopback,
// pipewire keeps running when its loopback is destroyed under it:
// RouteDevice and TogetherLink watch for the node going away and stop it.
// Thanks to the PipeWire developers: module-loopback and the config format are
// theirs, used from their documentation (no code copied).
const LOOPBACK_SCRIPT = [
    "d=$XDG_RUNTIME_DIR; [ \"${d#/}\" != \"$d\" ] || exit 1; l=$d/orbit-loopback.conf",
    "[ \"$(readlink \"$l\")\" = /dev/fd/3 ] || { ln -sfn /dev/fd/3 \"$l.$$\" && mv -fT \"$l.$$\" \"$l\"; } || exit 1",
    "q() { local s=${1//\\\\/\\\\\\\\}; printf '\"%s\"' \"${s//\\\"/\\\\\\\"}\"; }",
    "f=$(mktemp \"$d/orbit-loopback.XXXXXX\") || exit 1",
    "exec 3<>\"$f\"; rm -f -- \"$f\"",
    "printf 'context.properties = { log.level = 0 application.name = Orbit }\\ncontext.spa-libs = { audio.convert.* = audioconvert/libspa-audioconvert support.* = support/libspa-support }\\ncontext.modules = [ { name = libpipewire-module-rt flags = [ ifexists nofail ] } { name = libpipewire-module-protocol-native } { name = libpipewire-module-client-node } { name = libpipewire-module-adapter } { name = libpipewire-module-loopback args = { capture.props = %s playback.props = %s target.delay.sec = %s } } ]\\n' \"$(q \"$1\")\" \"$(q \"$2\")\" \"$(q \"${3:-0}\")\" >&3",
    "{ cat >/dev/null; kill \"$$\" 2>/dev/null; } <&0 3<&- &",
    "exec pipewire -c \"$l\" </dev/null"
].join("\n");

// Nothing is remembered by WirePlumber for the two ends Orbit creates. It goes
// at the start of each property string, before anything the caller wrote, so
// a value that never closes (a quote, a brace) cannot swallow it.
const FORGET = "state.restore-props=false state.restore-target=false ";

// The longest wait Orbit puts in a loopback (ms). A Bluetooth output can
// announce more than 600 ms (LDAC at its safest, a TV), and a wired copy or
// filter waits for what that adds; a second of stereo audio is under 400 KB.
var MAX_DELAY_MS = 1000;

function loopbackArgs(capture, playback, delaySeconds) {
    const args = ["bash", "-c", LOOPBACK_SCRIPT, "orbit", FORGET + capture, FORGET + playback];
    if (delaySeconds)
        args.push(String(delaySeconds));
    return args;
}

// The link group of one of Orbit's filters, the filter's own node name, set on
// both of its ends: set on one end only, WirePlumber sees two groups. A stream
// that carries the same group is taken as the filter's own and goes where the
// filter goes, the sink itself, never through the filter: the way for the
// volume tick to stay out of the copies (NAK-251). Thanks to WirePlumber's smart-filter rules for the idea, read in
// its documentation and find-filter-target.lua (no code copied).
function group(name) {
    return "node.link-group=" + name + " ";
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
    return loopbackArgs(group(name) + capture, group(name) + playback);
}

// --- The filter in front of a wired source (D298; it also keeps the volume tick out of the copies, NAK-251) ---
// Bluetooth is never delayed, so when the sound is taken from a wired output
// it is the wired output that waits, for what the Bluetooth ones add. The wait
// cannot be put in a copy (the apps play straight to that output), so a smart
// filter "orbit_wired_<key>" like the PC-level one is slipped in front of the
// output for as long as it is the source of a Listen together group, even with
// nothing to wait for. The copies read the filter's monitor, the sound before
// the wait, never the sink itself: the volume tick plays in the sink (see
// tickOutput), so it stays out of every copy (NAK-251).

var WIRED_PREFIX = "orbit_wired_";

// The filter's name for a wired output's sink name, "" when it is not one
function wiredFilterName(sink) {
    const key = Member.isWired(sink) ? Member.key(sink) : "";
    return key ? WIRED_PREFIX + key : "";
}

// Exactly the shape wiredFilterName gives (a name that goes into a property string)
function isWiredFilter(name) {
    return typeof name === "string" && name.length <= 60 && /^orbit_wired_w_[a-z0-9_]+$/.test(name);
}

// A wait as Together.delayArg writes it: seconds, at most three decimals
var DELAY_SECONDS = /^[0-9](\.[0-9]{1,3})?$/;

// The command of the filter in front of the wired output `sink` that waits
// `delaySeconds` (a text, from Together.delayArg; "" for no wait), or null when
// the sink is not a wired output's name or the wait is not a valid one or too
// long. Like the PC-level filter it dies with the shell, and its playback never
// falls back to another output: if the wired one goes away the sound stops
// instead of leaving through a speaker nobody chose.
function wiredFilterArgs(sink, delaySeconds, deviceName) {
    const name = wiredFilterName(sink);
    const delay = String(delaySeconds);
    const waits = delay !== "";
    if (!name || (waits && (!DELAY_SECONDS.test(delay) || Number(delay) <= 0 || Number(delay) * 1000 > MAX_DELAY_MS)))
        return null;
    const capture = "media.class=Audio/Sink node.name=" + name + " node.description=\"" + description(deviceName, "Wired output") + "\"" + " filter.smart=true filter.smart.name=" + name + " filter.smart.target={ node.name = \"" + sink + "\" }";
    const playback = "node.name=" + name + ".out node.passive=true node.dont-fallback=true";
    return loopbackArgs(group(name) + capture, group(name) + playback, delay);
}

// Clicking the planet: with one Bluetooth audio device connected, this PC
// goes quiet (the device keeps its level for later); with several (two
// headsets on one film), only that device does.
function muteTarget(audioDevices) {
    return audioDevices > 1 ? "device" : "pc";
}

// The nodes a level written to `node` must reach: when it is one of the
// `shared` PC-level nodes of a Listen together session, all of them (the
// members share one level, D254); else just itself
function levelNodes(shared, node) {
    return shared.indexOf(node) >= 0 ? shared : [node];
}

// The nodes whose output ticks for a level written to `node`: that node's
// alone, or every shared one when `group` says the hand moved the group's
// general level. The level of a member reaches the others (levelNodes) but
// the sound of its tick belongs to its own output (NAK-255).
function tickNodes(shared, node, group) {
    return group ? levelNodes(shared, node) : [node];
}

// A level written like a slider does: on every node it must reach, unmuted
function writeLevel(shared, node, level) {
    for (const n of levelNodes(shared, node)) {
        n.audio.muted = false;
        n.audio.volume = level;
    }
}

function writeMuted(shared, node, muted) {
    for (const n of levelNodes(shared, node))
        n.audio.muted = muted;
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
// "<device path>/sepN/fdM" (older BlueZ) or "<device path>/fdM" (BlueZ 5.87).
function transportPath(tree, devicePath) {
    if (!Address.isDevicePath(devicePath))
        return "";
    const lines = String(tree || "").split("\n");
    for (let i = 0; i < lines.length; i++) {
        const p = lines[i].trim();
        if (p.indexOf(devicePath + "/") === 0 && /^(\/sep[0-9]+)?\/fd[0-9]+$/.test(p.slice(devicePath.length)))
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

// Which levels the scope shows, from the nodes AudioRoute gives
// (deviceNode, pcNode). Both: two half circles. Only one level (a device
// with no level of its own, "Separate PC volume" off, or an output that is
// not Bluetooth): that one alone, as the "pc" half. "ownIcon" tells the
// lone half is the device's own level, so its foot shows the device.
function shownLevels(deviceNode, pcNode) {
    if (deviceNode && pcNode)
        return { "device": deviceNode, "pc": pcNode, "ownIcon": false };
    return { "device": null, "pc": pcNode || deviceNode || null, "ownIcon": !pcNode && !!deviceNode };
}
