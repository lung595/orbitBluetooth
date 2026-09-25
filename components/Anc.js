.pragma library

// Pure helpers for headphone noise control (no QML, testable with gjs).
// The Python helper in anc/ speaks the vendor protocols; this file decides
// which protocol family a device belongs to and how modes are presented.

// Name patterns -> protocol family (anc/protocols/<family>.py).
// Order matters: the first match wins.
var FAMILIES = [
    // Sony: WH-1000XM3+, WF-1000XM3+, WH-CH720N, WF-C700N, LinkBuds, ULT WEAR, INZONE Buds
    ["sony", /\b(WH|WF|WI)-[A-Z0-9]+|LinkBuds|ULT WEAR|INZONE Buds/i],
    ["apple", /AirPods|Beats|Powerbeats/i],
    ["nothing", /^Nothing\b|^Ear ?\((1|2|3|a|stick|open)\)|^CMF |Headphone ?\(1\)/i],
    ["samsung", /Galaxy Buds|^Buds(2|3|\+| Pro| Live| FE| ?Core)/i],
    ["bose", /Bose|QuietComfort|\bQC ?(35|45|Ultra|Earbuds)|\bNC ?700|Noise Cancelling Headphones 700/i],
    ["soundcore", /Soundcore|Life ?Q\d+|Liberty ?(Air|4|3|2)|Space ?(Q45|One|A40)|Anker/i]
];

// Returns the protocol family for a device name, or "" when unknown.
function family(name) {
    if (!name)
        return "";
    for (var i = 0; i < FAMILIES.length; i++)
        if (FAMILIES[i][1].test(name))
            return FAMILIES[i][0];
    return "";
}

var LABELS = {
    "nc": "Noise cancelling",
    "ambient": "Ambient",
    "off": "Off",
    "adaptive": "Adaptive"
};

var SHORT = {
    "nc": "Silence",
    "ambient": "Ambient",
    "off": "Off",
    "adaptive": "Adaptive"
};

// Material Symbols names used by DankIcon
var ICONS = {
    "nc": "noise_aware",
    "ambient": "hearing",
    "off": "noise_control_off",
    "adaptive": "auto_awesome"
};

// Display order in the segmented control, whatever order the headset reports
var ORDER = ["nc", "adaptive", "ambient", "off"];

function ordered(modes) {
    return ORDER.filter(function (m) {
        return (modes || []).indexOf(m) >= 0;
    });
}

// The mode after `current` for a right-click or `ancCycle`. "off" is skipped
// when possible: people cycle between hearing more and hearing less.
function nextMode(modes, current) {
    var list = ordered(modes);
    var loop = list.filter(function (m) {
        return m !== "off";
    });
    if (loop.length < 2)
        loop = list;
    if (!loop.length)
        return "";
    var i = loop.indexOf(current);
    return loop[(i + 1) % loop.length];
}

// Battery parts in reading order, with short labels
var PARTS = [["left", "L"], ["right", "R"], ["case", "Case"], ["single", ""]];

function batteryParts(battery) {
    var out = [];
    for (var i = 0; i < PARTS.length; i++) {
        var b = battery ? battery[PARTS[i][0]] : null;
        if (b && b.level >= 0)
            out.push({
                "part": PARTS[i][0],
                "label": PARTS[i][1],
                "level": b.level,
                "charging": !!b.charging
            });
    }
    return out;
}

// Human text for a helper error line
function errorText(error) {
    if (!error)
        return "";
    if (error === "unsupported")
        return "This model is not supported yet";
    if (/not found/.test(error))
        return "Noise control not available on this model";
    if (/refused|denied|busy|reset/i.test(error))
        return "The headset refused the control channel";
    if (/timed out/i.test(error))
        return "The headset did not answer";
    return "Noise control unavailable";
}
