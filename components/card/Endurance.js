.pragma library

// Rated battery life, for a time-left estimate from the first second of a
// connection (before the level has dropped enough to measure the real
// drain). Figures are the makers' published hours on a full charge, with
// noise cancelling on and off; earbuds are per charge of the buds, without
// the case. The estimate is always shown with "≈" and is replaced by the
// measured drain as soon as there is one (see Charge.analyze).

// [name pattern, hours with noise cancelling, hours without]
var MODELS = [
    [/WH-1000XM6|WH-1000XM5/i, 30, 40],
    [/WH-1000XM4|WH-1000XM3/i, 30, 38],
    [/WF-1000XM5|WF-1000XM4/i, 8, 12],
    [/WH-CH720N/i, 35, 50],
    [/AirPods Max/i, 20, 20],
    [/AirPods Pro 3/i, 8, 10],
    [/AirPods Pro/i, 6, 7],
    [/AirPods 4/i, 4, 5],
    [/AirPods/i, 5, 5],
    [/Buds3 Pro|Buds 3 Pro/i, 6, 7],
    [/Buds2 Pro|Buds 2 Pro/i, 5, 8],
    [/Buds FE/i, 6, 8.5],
    [/Galaxy Buds|Buds2|Buds3/i, 5, 7],
    [/QC Ultra Earbuds|QuietComfort Ultra Earbuds/i, 6, 6],
    [/QC Ultra|QuietComfort Ultra|QC ?45|QuietComfort 45/i, 24, 24],
    [/QC ?35|QuietComfort 35/i, 20, 20],
    [/Nothing Headphone|Headphone \(1\)/i, 35, 80],
    [/Ear \(a\)/i, 5.5, 9.5],
    [/Nothing Ear|^Ear ?\(|^CMF Buds/i, 4, 6],
    [/Space Q45/i, 50, 65],
    [/Life Q30|Life Q35/i, 40, 60],
    [/FreeBuds Pro/i, 4.5, 6.5],
    [/FreeBuds/i, 6, 7.5],
    [/Redmi Buds/i, 6, 8],
    [/Xbox Wireless Controller/i, 40, 40],
    [/DualSense Edge/i, 5, 5],
    [/DualSense|Wireless Controller/i, 6, 6]
];

// Rough fallbacks by device type (Glyphs.js kinds), for unlisted models
var KINDS = {
    "headphones": [25, 35],
    "headphonesSlim": [25, 35],
    "headphonesPremium": [25, 35],
    "headset": [15, 20],
    "earbudsStem": [5, 7],
    "earbudsRound": [5, 7],
    "earbudsCase": [5, 7],
    "speaker": [12, 12],
    "speakerTall": [12, 12]
};

// Hours on a full charge for this device right now, or 0 when unknown.
// Noise cancelling (and adaptive, ambient) costs power; "off" or no noise
// control data uses the longer figure only when the mode is known to be off.
function ratedHours(name, kind, ancMode) {
    var pair = null;
    for (var i = 0; i < MODELS.length && !pair; i++)
        if (MODELS[i][0].test(name || ""))
            pair = MODELS[i];
    var hours = pair ? [pair[1], pair[2]] : KINDS[kind];
    if (!hours)
        return 0;
    return ancMode === "off" ? hours[1] : hours[0];
}
