.pragma library
.import "../common/Text.js" as Text

// Which wired outputs are plugged in right now (D298), read from
// `pactl --format=json list sinks`: the headset on a USB cable, an audio
// interface, a jack or HDMI with something connected. Listen together offers
// them next to the Bluetooth outputs. Pure: no process, no QML; the caller
// runs command() and hands the text to parse(). Tested by tests/wired.test.js.
//
// Only what is plugged in is listed. A wired output is told apart by its
// sink's name ("alsa_output.<...>"): Bluetooth sinks (bluez_output.*), Orbit's
// own virtual nodes (orbit_*) and anything that is not a sound card never
// match, so the sound is never copied onto something Orbit made itself.

// The text is data from a program we do not control: never read more than this
var MAX_TEXT = 200000;
// A half circle only holds so many arcs, and a list longer than this is noise
var MAX_OUTPUTS = 16;
var FALLBACK_LABEL = "Wired output";

// The sink's node name becomes a command argument later: the shape is checked
// here, once, so every consumer can trust it
var SINK_NAME = /^alsa_output\.[A-Za-z0-9_.+\-]{1,150}$/;

// The exact command, as an argument list: never a shell string
function command() {
    return ["pactl", "--format=json", "list", "sinks"];
}

// A sink's description (written by the driver, or by whoever plugged the
// device) as a short line the card can show
function labelOf(description) {
    return Text.line(description) || FALLBACK_LABEL;
}

// A property read as a short lower case word ("usb", "headset"), "" otherwise
function _word(value) {
    return typeof value === "string" && /^[A-Za-z0-9_\-]{1,24}$/.test(value) ? value.toLowerCase() : "";
}

// Not a physical output: a monitor, a loopback or a node an app made up
function _virtual(sink, props) {
    return /\.monitor$|loopback/i.test(sink)
        || props["device.class"] === "monitor"
        || props["node.virtual"] === "true"
        || (props["media.class"] !== undefined && props["media.class"] !== "Audio/Sink");
}

// Is something plugged in? It is the ACTIVE port that tells. A port is only
// "not available" when the driver can sense the connector and finds it empty
// (a jack, HDMI); a USB DAC cannot be sensed, so it says "availability unknown"
// or has no port at all, and counts as plugged. A sink whose ports exist but
// none is active has nothing to play on.
function _plugged(sink) {
    const ports = Array.isArray(sink.ports) ? sink.ports : [];
    if (!ports.length)
        return true;
    const active = ports.find(p => p && p.name === sink.active_port);
    return !!active && active.availability !== "not available";
}

// One sink of the listing -> its entry, or null when it is not a plugged wired output
function _entry(sink) {
    if (!sink || typeof sink !== "object" || typeof sink.name !== "string" || !SINK_NAME.test(sink.name))
        return null;
    const props = sink.properties && typeof sink.properties === "object" ? sink.properties : {};
    if (_virtual(sink.name, props) || !_plugged(sink))
        return null;
    return {
        "sink": sink.name,
        "label": labelOf(sink.description),
        "bus": _word(props["device.bus"]),
        // pactl spells it with an underscore, PipeWire's own nodes with a hyphen
        "formFactor": _word(props["device.form_factor"] || props["device.form-factor"]),
        "plugged": true
    };
}

// By name, then by sink so that two outputs with the same name keep a stable order
function _byLabel(a, b) {
    const x = a.label.toLowerCase(), y = b.label.toLowerCase();
    if (x !== y)
        return x < y ? -1 : 1;
    return a.sink < b.sink ? -1 : a.sink > b.sink ? 1 : 0;
}

// The wired outputs among `sinks` (as pactl lists them), sorted, at most MAX_OUTPUTS
function _listing(sinks) {
    const seen = {};
    const found = [];
    for (const sink of sinks) {
        const entry = _entry(sink);
        // The sink's name is its identity: a repeat is the same output
        if (entry && !seen[entry.sink]) {
            seen[entry.sink] = true;
            found.push(entry);
        }
    }
    return found.sort(_byLabel).slice(0, MAX_OUTPUTS);
}

// The command's text -> the plugged wired outputs, sorted, at most MAX_OUTPUTS:
// [{ sink, label, bus, formFactor, plugged }]. Anything unreadable gives [].
function parse(jsonText) {
    if (typeof jsonText !== "string" || jsonText.length > MAX_TEXT)
        return [];
    let sinks;
    try {
        sinks = JSON.parse(jsonText);
    } catch (e) {
        return [];
    }
    return Array.isArray(sinks) ? _listing(sinks) : [];
}

// The same outputs from the sinks PipeWire holds right now (Quickshell's node
// list), for what cannot wait for a command: [{ sink, label, bus, formFactor }],
// sorted, at most MAX_OUTPUTS. A node cannot tell whether something is plugged
// into its connector, so every wired output PipeWire lists is here: those
// Listen together accepts.
function fromNodes(nodes) {
    const sinks = [];
    for (let i = 0; nodes && i < nodes.length; i++) {
        const n = nodes[i];
        if (n && n.isSink && !n.isStream)
            sinks.push({ "name": n.name, "description": n.nickname || n.description, "properties": n.properties });
    }
    return _listing(sinks).map(e => ({ "sink": e.sink, "label": e.label, "bus": e.bus, "formFactor": e.formFactor }));
}

// What picture the interface draws: "usb", "hdmi", "analog" or "other"
// (S/PDIF, a sound card it cannot name). The connection beats the name: a USB
// dock with an HDMI profile is still a USB device.
function kindOf(entry) {
    const e = entry || {};
    const sink = typeof e.sink === "string" ? e.sink : "";
    if (e.bus === "usb" || /^alsa_output\.usb-/.test(sink))
        return "usb";
    if (/hdmi|display-?port/i.test(sink))
        return "hdmi";
    if (/analog/i.test(sink) || /^(headphones?|headset|speaker|internal)$/.test(e.formFactor || ""))
        return "analog";
    return "other";
}

// The same picture from a PipeWire node (its name and properties, which may be
// missing)
function kindOfNode(node) {
    const n = node && typeof node === "object" ? node : {};
    const p = n.properties && typeof n.properties === "object" ? n.properties : {};
    return kindOf({
        "sink": n.name,
        "bus": _word(p["device.bus"]),
        "formFactor": _word(p["device.form_factor"] || p["device.form-factor"])
    });
}

// The icon (a Material Symbol) of a kind of output, for the arcs of the volume
// wheel; the orbit draws its own pictures. Anything else is the plain speaker.
var ICONS = { "usb": "usb", "hdmi": "settings_input_hdmi", "analog": "cable", "other": "speaker" };
function iconOf(kind) {
    return ICONS.hasOwnProperty(kind) ? ICONS[kind] : ICONS.other;
}

// What `dms ipc call orbitBluetooth togetherOutputs` says of each output of a
// listing: the node name `together` takes, the name to show, the kind of
// picture, and whether it already takes part (`members` are the session's)
function describe(outputs, members) {
    const taking = Array.isArray(members) ? members : [];
    return (Array.isArray(outputs) ? outputs : []).map(o => ({
        "output": o.sink,
        "name": o.label,
        "kind": kindOf(o),
        "member": taking.indexOf(o.sink) >= 0
    }));
}

// Do two listings hold the same outputs? Lists from parse() are sorted, so a
// pair-by-pair comparison is enough; the caller restarts nothing when true.
function sameSet(a, b) {
    const x = Array.isArray(a) ? a : [], y = Array.isArray(b) ? b : [];
    return x.length === y.length && x.every((e, i) =>
        e.sink === y[i].sink && e.label === y[i].label && e.bus === y[i].bus
        && e.formFactor === y[i].formFactor && e.plugged === y[i].plugged);
}
