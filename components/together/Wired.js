.pragma library

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
// A label that fits a card without being cut by the interface
var MAX_LABEL = 40;
var FALLBACK_LABEL = "Wired output";

// The sink's node name becomes a command argument later: the shape is checked
// here, once, so every consumer can trust it
var SINK_NAME = /^alsa_output\.[A-Za-z0-9_.+\-]{1,150}$/;

// Control characters, plus the invisible ones that could reorder or hide text
// (zero width, bidi overrides, byte order mark). Written as ranges: the engine
// behind QML does not take \p{...} on every Qt version.
var UNSEEN = /[\u0000-\u001f\u007f-\u009f​-‏‪-‮⁠-⁤⁦-⁩﻿]/g;

// The exact command, as an argument list: never a shell string
function command() {
    return ["pactl", "--format=json", "list", "sinks"];
}

// A sink's description (written by the driver, or by whoever plugged the
// device) as a short line the card can show
function labelOf(description) {
    const text = typeof description === "string" ? description : "";
    const line = text.replace(UNSEEN, " ").replace(/\s+/g, " ").trim();
    // Cut by characters, not by UTF-16 units, so an emoji is never split in two
    return Array.from(line).slice(0, MAX_LABEL).join("").trim() || FALLBACK_LABEL;
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
        "formFactor": _word(props["device.form_factor"]),
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
    if (!Array.isArray(sinks))
        return [];
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

// Do two listings hold the same outputs? Lists from parse() are sorted, so a
// pair-by-pair comparison is enough; the caller restarts nothing when true.
function sameSet(a, b) {
    const x = Array.isArray(a) ? a : [], y = Array.isArray(b) ? b : [];
    return x.length === y.length && x.every((e, i) =>
        e.sink === y[i].sink && e.label === y[i].label && e.bus === y[i].bus
        && e.formFactor === y[i].formFactor && e.plugged === y[i].plugged);
}
