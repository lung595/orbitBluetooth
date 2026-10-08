.pragma library

// What a Bluetooth codec is (D260): its name as people write it, what it
// carries, and its bit rate when that is honestly known. Pure: no process,
// no QML. Audiophile.js uses it for the facts of an output.

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
    "opus_05": "Opus",
    "cvsd": "CVSD",
    "msbc": "mSBC",
    "lc3_swb": "LC3-SWB"
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

// The Bluetooth profile PipeWire reports, as people write it; the first
// pattern that matches wins, an unknown one is shown as PipeWire names it
var PROFILES = [
    { "match": /^a2dp/, "name": "A2DP" },
    { "match": /^(headset|hfp|hsp)/, "name": "HSP/HFP" },
    { "match": /^(bap|asha)/, "name": "LE Audio" }
];

// LDAC's three fixed qualities (kbit/s), by sample rate family: the
// 44.1 / 88.2 kHz family runs a little lower than the 48 / 96 kHz one
var LDAC_KBPS = { "0": [990, 909], "1": [660, 606], "2": [330, 303] };
// aptX and aptX HD squeeze 16 / 24-bit samples four to one, always
var APTX_RATIO = 4;

function name(key) {
    return key ? (CODECS[key] || key.toUpperCase()) : "";
}

// What the codec carries, in bits; 0 when it is not known
function bits(key) {
    return CODEC_BITS[key] || 0;
}

function profile(key) {
    if (!key)
        return "";
    const known = PROFILES.find(p => p.match.test(key));
    return known ? known.name : key;
}

// LDAC: PipeWire's `quality` is the setting (-1 adaptive, 0 high, 1
// standard, 2 mobile); a fixed one is a known rate, adaptive is a range
function _ldac(rate, quality) {
    const family = rate % 44100 === 0 ? 1 : 0;
    if (quality === -1)
        return "Adaptive, " + LDAC_KBPS["2"][family] + " to " + LDAC_KBPS["0"][family] + " kbps";
    const kbps = LDAC_KBPS[String(quality)];
    return kbps ? kbps[family] + " kbps" : "";
}

// The codec's bit rate as text, or "" when it is not known for sure. SBC,
// AAC and the rest vary with the link and PipeWire does not say which rate
// is in use: they show nothing rather than a guess. `quality` is LDAC's
// setting as read from the sink (undefined when not read)
function bitrate(key, rate, channels, quality) {
    if (!rate)
        return "";
    if (key === "ldac")
        return quality === undefined ? "" : _ldac(rate, quality);
    if ((key === "aptx" || key === "aptx_ll" || key === "aptx_hd") && channels)
        return Math.floor(rate * channels * bits(key) / APTX_RATIO / 1000) + " kbps";
    return "";
}
