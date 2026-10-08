.pragma library

// How a battery level is told apart at a glance (the arc around a device's
// disc): a colour that drifts with the level, red to amber to green, and a look
// of its own while charging. Pure: the QML maps each tone to a colour of the
// theme and blends two of them (BodyArcs), the numbers live here and nowhere
// else (the card's ramp borrows the red limit: Charge.js).
// Tested by tests/battery.test.js.

var CRITICAL_MAX = 15;      // % and down: red, nothing left to spare
var LOW_AT = 35;            // %: amber; above it the arc drifts toward green, which it reaches at 100 %

// The two tones a level lies between and how far from the first to the second
// (0..1), or the tone of a charging device (whatever the level: what is being
// filled is not judged by how empty it still is). A level that moves a point
// moves the colour, so the arc says more than a threshold would.
function stretch(level, charging) {
    if (charging)
        return { "from": "charging", "to": "charging", "t": 0 };
    const l = Math.max(0, Math.min(100, level));
    if (l <= CRITICAL_MAX)
        return { "from": "critical", "to": "critical", "t": 0 };
    if (l <= LOW_AT)
        return { "from": "critical", "to": "low", "t": (l - CRITICAL_MAX) / (LOW_AT - CRITICAL_MAX) };
    return { "from": "low", "to": "ok", "t": (l - LOW_AT) / (100 - LOW_AT) };
}

// A number a share `t` of the way from `a` to `b`
function along(a, b, t) {
    return a + (b - a) * t;
}

// A hue (0..1) a share `t` of the way from `a` to `b` the short way round the
// wheel: a red at 0.98 and an amber at 0.1 meet through orange, never through
// cyan. A grey has no hue (Qt says -1): the other one's is kept.
function hueMix(a, b, t) {
    if (a < 0)
        return b;
    if (b < 0)
        return a;
    let d = b - a;
    if (d > 0.5)
        d -= 1;
    else if (d < -0.5)
        d += 1;
    return (a + d * t + 1) % 1;
}
