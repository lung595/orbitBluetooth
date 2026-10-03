.pragma library

// Pure logic of the polar vectorscope (PolarScope.qml), tested in
// tests/anc.test.js. Angles are in degrees, clockwise from the right, as
// QtQuick.Shapes' PathAngleArc counts them (y points down): left is 180,
// the top is 270, right is 360.
//
// The outer half circle is the device's own level, the inner one this PC's
// (D250). Each lights up from the left to its level. Listening together
// (D254) splits the outer half at the top: the first device lights its
// left quarter, the second its right quarter, each from its bottom corner.

var LEFT = 180;
var TOP = 270;
var RIGHT = 360;

function clamp01(v) {
    return Math.max(0, Math.min(1, Number(v) || 0));
}

// Where an arc starts and how far it goes: "outer", "inner", "d1", "d2"
function arc(part, level) {
    const v = clamp01(level);
    if (part === "d1")
        return { "start": LEFT, "sweep": 90 * v };
    if (part === "d2")
        return { "start": RIGHT, "sweep": -90 * v };
    return { "start": LEFT, "sweep": 180 * v };
}

// The moon at the lit end of an arc
function end(part, level) {
    const a = arc(part, level);
    return a.start + a.sweep;
}

function point(cx, cy, r, deg) {
    const a = deg * Math.PI / 180;
    return { "x": cx + Math.cos(a) * r, "y": cy + Math.sin(a) * r };
}

// The pointer's angle, 0..360 with the top at 270; below the baseline it
// snaps to the nearer end, so a drag that slips under still makes sense
function angleOf(dx, dy) {
    let deg = Math.atan2(dy, dx) * 180 / Math.PI;
    if (deg < 0)
        deg += 360;
    if (deg < 180 && deg > 0)
        return deg < 90 ? RIGHT : LEFT;
    return deg === 0 ? RIGHT : deg;
}

// The level under the pointer, for a drag along an arc
function valueAt(part, dx, dy) {
    const deg = angleOf(dx, dy);
    if (part === "d1")
        return clamp01((deg - LEFT) / 90);
    if (part === "d2")
        return clamp01((RIGHT - deg) / 90);
    return clamp01((deg - LEFT) / 180);
}

// Which arc the pointer is on: "outer" (or "d1"/"d2" when split), "inner",
// or "". `grip` is how far from the line a press still counts.
function zone(dx, dy, outer, inner, grip, split) {
    if (dy > grip)
        return "";
    const d = Math.sqrt(dx * dx + dy * dy);
    if (Math.abs(d - outer) <= grip)
        return split ? (dx < 0 ? "d1" : "d2") : "outer";
    if (Math.abs(d - inner) <= grip)
        return "inner";
    return "";
}

// One line of cava's raw ascii output ("9;35;...;9;"), `bars` values per
// channel side by side: the left channel comes first with its low notes in
// the middle, then the right one. Values 0..100 -> 0..1, low notes first.
function parseFrame(line, bars) {
    const parts = String(line || "").split(";");
    if (parts.length && parts[parts.length - 1].trim() === "")
        parts.pop();
    if (parts.length !== bars * 2)
        return null;
    const l = [], r = [];
    for (let i = 0; i < bars * 2; i++) {
        const v = parseInt(parts[i], 10);
        if (!(v >= 0 && v <= 100))
            return null;
        if (i < bars)
            l.unshift(v / 100);
        else
            r.push(v / 100);
    }
    return { "l": l, "r": r };
}

function loudness(frame) {
    if (!frame)
        return 0;
    let m = 0;
    for (let i = 0; i < frame.l.length; i++)
        m = Math.max(m, frame.l[i], frame.r[i]);
    return m;
}

// A new point of the cloud from one frequency band of a frame: its angle
// says where the sound sits (left, center, right), its distance from the
// center how loud it is. u1..u3 are random numbers in 0..1 (passed in so
// tests stay exact). Null when that band is silent.
function spawn(frame, band, radius, u1, u2, u3) {
    if (!frame || band < 0 || band >= frame.l.length)
        return null;
    const l = frame.l[band], r = frame.r[band];
    const a = Math.max(l, r);
    if (a < 0.03)
        return null;
    const pan = (r - l) / (l + r);
    const spread = 34 * (1 - 0.6 * Math.abs(pan));
    const deg = Math.max(LEFT + 3, Math.min(RIGHT - 3, TOP + pan * 87 + (u1 - 0.5) * spread));
    const dist = radius * Math.pow(a, 0.7) * (0.55 + 0.45 * u2);
    return {
        "deg": deg,
        "dist": dist,
        "size": 1.6 + 2.2 * u3 * (1 - band / frame.l.length * 0.5),
        "life": 0
    };
}

// The cava configuration: stereo, raw numbers, from a sound output's
// monitor; null for a name that could carry anything else (value 11)
function cavaConfig(source, fps, bars) {
    if (!/^[A-Za-z0-9_.:-]{1,160}$/.test(String(source || "")))
        return null;
    return ["[general]", "framerate = " + Math.max(10, Math.min(60, fps | 0)), "bars = " + (bars * 2),
        "[input]", "method = pulse", "source = " + source,
        "[output]", "method = raw", "channels = stereo", "data_format = ascii", "ascii_max_range = 100",
        "bar_delimiter = 59", "frame_delimiter = 10", ""].join("\n");
}
