.pragma library

// What an audio output is, read from `pactl --format=json list sinks`
// (D260): how it is connected, the codec, the sample rate, the bit depth,
// the channels, and whether this PC resamples on the way. Pure: no process,
// no QML; AudioFacts.qml runs the command and hands its text here.

// Every fact the user can show, in display order: the key (also the
// settings' suffix), the label of the detail view, and the defaults
// (on the card's line; in the detail view)
var INFOS = [
    { "key": "connection", "label": "Connection", "card": true, "more": true },
    { "key": "codec", "label": "Codec", "card": true, "more": true },
    { "key": "rate", "label": "Sample rate", "card": true, "more": true },
    { "key": "bits", "label": "Bit depth", "card": true, "more": true },
    { "key": "channels", "label": "Channels", "card": false, "more": true },
    { "key": "chain", "label": "PC to device", "card": false, "more": true }
];

// Names PipeWire gives Bluetooth codecs, as people write them
var CODECS = {
    "sbc": "SBC",
    "sbc_xq": "SBC-XQ",
    "aac": "AAC",
    "aptx": "aptX",
    "aptx_hd": "aptX HD",
    "aptx_ll": "aptX LL",
    "aptx_ll_duplex": "aptX LL",
    "aptx_adaptive": "aptX Adaptive",
    "ldac": "LDAC",
    "lc3": "LC3",
    "lc3plus_hr": "LC3plus",
    "faststream": "FastStream",
    "opus_05": "Opus"
};
// What a Bluetooth codec carries; PipeWire's sink format says nothing
// about it (a 32-bit float sink can feed a 16-bit codec)
var CODEC_BITS = {
    "sbc": 16,
    "sbc_xq": 16,
    "aac": 16,
    "aptx": 16,
    "aptx_ll": 16,
    "aptx_hd": 24,
    "aptx_adaptive": 24,
    "ldac": 24,
    "lc3": 24,
    "lc3plus_hr": 24
};
var CHANNEL_NAMES = { 1: "Mono", 2: "Stereo", 6: "5.1", 8: "7.1" };

// "s32le 2ch 192000Hz" -> { bits, channels, rate }, or null
function _spec(text) {
    const m = /^(\S+)\s+(\d+)ch\s+(\d+)Hz$/.exec(text || "");
    if (!m)
        return null;
    const depth = /(\d+)/.exec(m[1]);
    return { "bits": depth ? parseInt(depth[1]) : 0, "channels": parseInt(m[2]), "rate": parseInt(m[3]) };
}

// How the output is connected: "Bluetooth", "USB", "HDMI", "S/PDIF" (optical
// or coaxial) or "Analog"; "" when PipeWire does not say
function connectionOf(name, props) {
    const p = props || {};
    if (/^bluez_/.test(name || "") || p["api.bluez5.codec"] || p["device.api"] === "bluez5")
        return "Bluetooth";
    const path = p["api.alsa.path"] || "";
    if (/^hdmi/.test(path) || /hdmi/i.test(name || ""))
        return "HDMI";
    if (/^iec958/.test(path))
        return "S/PDIF";
    if (p["device.bus"] === "usb")
        return "USB";
    return p["device.api"] === "alsa" ? "Analog" : "";
}

// One sink of the listing -> its facts (empty strings / 0 where unknown)
function factsOf(sink) {
    const props = sink.properties || {};
    const spec = _spec(sink.sample_specification) || { "bits": 0, "channels": 0, "rate": 0 };
    const codecKey = props["api.bluez5.codec"] || "";
    return {
        "connection": connectionOf(sink.name, props),
        "codec": codecKey ? (CODECS[codecKey] || codecKey.toUpperCase()) : "",
        "rate": spec.rate,
        "bits": codecKey && CODEC_BITS[codecKey] ? CODEC_BITS[codecKey] : spec.bits,
        "channels": spec.channels
    };
}

// The listing's text -> { sink name: facts }; {} when it is not JSON
function parse(text) {
    let list;
    try {
        list = JSON.parse(text);
    } catch (e) {
        return {};
    }
    const out = {};
    if (!Array.isArray(list))
        return out;
    for (const sink of list)
        if (sink && typeof sink.name === "string")
            out[sink.name] = factsOf(sink);
    return out;
}

function kilohertz(rate) {
    if (!rate)
        return "";
    const k = rate / 1000;
    return (Number.isInteger(k) ? k : Math.round(k * 10) / 10) + " kHz";
}

// This PC mixes at one rate and the device plays at another: PipeWire
// resamples in between. "" when they match or one is unknown
function chainOf(pc, device) {
    if (!pc || !device || !pc.rate || !device.rate || pc.rate === device.rate)
        return "";
    return "Resampled " + kilohertz(pc.rate) + " to " + kilohertz(device.rate);
}

// The text of one fact, "" when there is none to show
function textOf(key, facts, pc) {
    if (!facts)
        return "";
    switch (key) {
    case "connection":
    case "codec":
        return facts[key];
    case "rate":
        return kilohertz(facts.rate);
    case "bits":
        return facts.bits ? facts.bits + " bit" : "";
    case "channels":
        return CHANNEL_NAMES[facts.channels] || (facts.channels ? facts.channels + " channels" : "");
    case "chain":
        return chainOf(pc, facts);
    }
    return "";
}

// The card's line: the chosen facts, in order, "Bluetooth · LDAC · 96 kHz"
function line(facts, chosen, pc) {
    const parts = [];
    for (const info of INFOS) {
        const t = chosen[info.key] ? textOf(info.key, facts, pc) : "";
        if (t)
            parts.push(t);
    }
    return parts.join(" · ");
}

// The detail view: [{ label, text }] for the chosen facts that exist
function rows(facts, chosen, pc) {
    const out = [];
    for (const info of INFOS) {
        const t = chosen[info.key] ? textOf(info.key, facts, pc) : "";
        if (t)
            out.push({ "label": info.label, "text": t });
    }
    return out;
}
