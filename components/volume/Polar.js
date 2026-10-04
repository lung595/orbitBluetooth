.pragma library

// Pure logic of the polar vectorscope (PolarScope.qml), tested in
// tests/*.test.js. Angles are in degrees, clockwise from the right, as
// QtQuick.Shapes' PathAngleArc counts them (y points down): left is 180,
// the top is 270, right is 360.
//
// The inner half circle is this PC's level (D250). The outer one is the
// device's own, one arc. Listening together (D254, D277) the outer half is
// cut into one arc per output (2 to 4, in the order they joined, left to
// right), each lit from the end farthest from the top so that it grows
// toward the top. A part is named "pc", "device" (the one outer arc) or
// "m0".."m3" (the arcs of the outputs listening together).

var LEFT = 180;
var TOP = 270;
var RIGHT = 360;
// The most outputs that can listen together, and the space left between two
// neighbouring arcs of the outer half (in degrees, half on each side)
var MAX_MEMBERS = 4;
var GAP = 4;

function clamp01(v) {
    return Math.max(0, Math.min(1, Number(v) || 0));
}

// --- The arcs of the outer half circle ------------------------------------------

// `count` equal arcs of the half circle (1: the device's own, 2..4: the
// outputs listening together), each trimmed by half the gap where it meets
// a neighbour. `reverse` tells where it lights from: the right end when the
// arc lies right of the top, the left end otherwise, so every arc grows
// toward the top; the middle one of an odd count, which has no side, lights
// from the left, like the single arc.
function slices(count) {
    const n = Math.max(1, Math.min(MAX_MEMBERS, count | 0));
    const width = 180 / n;
    const out = [];
    for (let i = 0; i < n; i++) {
        const from = LEFT + i * width, to = from + width;
        out.push({
            "start": from + (i > 0 ? GAP / 2 : 0),
            "end": to - (i < n - 1 ? GAP / 2 : 0),
            "reverse": (from + to) / 2 > TOP + 1e-9
        });
    }
    return out;
}

// Which of the `count` arcs an angle belongs to (gaps and ends included)
function sliceAt(deg, count) {
    const n = Math.max(1, Math.min(MAX_MEMBERS, count | 0));
    return Math.max(0, Math.min(n - 1, Math.floor((deg - LEFT) / (180 / n))));
}

// The part an arc is called: "device" for the one outer arc, else "m<i>"
function partOf(index, count) {
    return count >= 2 ? "m" + index : "device";
}

// The arc a part is (0 for "device"), or -1 for "pc" and anything else
function indexOf(part) {
    if (part === "device")
        return 0;
    const m = /^m([0-3])$/.exec(String(part));
    return m ? Number(m[1]) : -1;
}

// Where an arc starts and how far it goes at a level (0..1)
function arc(slice, level) {
    const span = slice.end - slice.start;
    const v = clamp01(level);
    return slice.reverse ? { "start": slice.end, "sweep": -span * v } : { "start": slice.start, "sweep": span * v };
}

// The moon at the lit end of an arc
function end(slice, level) {
    const a = arc(slice, level);
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
function valueAt(slice, dx, dy) {
    const deg = angleOf(dx, dy);
    return clamp01((slice.reverse ? slice.end - deg : deg - slice.start) / (slice.end - slice.start));
}

// Which arc the pointer is on, as a part: "pc" (the inner half), the part of
// an outer arc (`count` of them, 0 when the output has no level of its own),
// or "". `grip` is how far from the line a press still counts.
function zone(dx, dy, outer, inner, grip, count) {
    if (dy > grip)
        return "";
    const d = Math.sqrt(dx * dx + dy * dy);
    if (count > 0 && Math.abs(d - outer) <= grip)
        return partOf(sliceAt(angleOf(dx, dy), count), count);
    return Math.abs(d - inner) <= grip ? "pc" : "";
}

// The level a wheel notch belongs to, from the pointer's place relative to
// the center (D275). Every spot answers, none is dead: beside the half
// circles, where the percentages sit, the left one is the first output's and
// the right one the second's (this PC's with a single output); anywhere else
// the nearer arc wins, so an arc, the icon at its foot and the gap beside it
// all pick one side. `count` outer arcs: 0 for an output with no level of its
// own (always this PC's).
function wheelPart(dx, dy, outer, inner, sideNumbers, count) {
    if (count < 1)
        return "pc";
    if (sideNumbers && Math.abs(dx) > outer)
        return dx < 0 ? partOf(0, count) : count >= 2 ? partOf(1, count) : "pc";
    if (Math.sqrt(dx * dx + dy * dy) < (outer + inner) / 2)
        return "pc";
    return partOf(sliceAt(angleOf(dx, dy), count), count);
}

// Where the icon of arc `index` (of `count`) is centred: at the foot of the
// half circle for the first and the last arc (they start at the ends), else
// inside the arc, by the end it lights from, clear of the line so a press on
// the icon is never taken for a drag. `size` is the icon's.
function iconSpot(index, count, cx, cy, outer, size) {
    const foot = cy + 6 + size / 2;
    if (index === 0)
        return { "x": cx - outer, "y": foot };
    if (index >= count - 1)
        return { "x": cx + outer, "y": foot };
    const s = slices(count)[index];
    return point(cx, cy, outer - size * 1.6, s.reverse ? s.end : s.start);
}

// Where the name and level of an arc are written when there are more than
// two: out from the middle of the arc, leaning away from the centre on its
// own side (`align`: the text ends there on the left, starts there on the
// right, is centred at the top), whatever the levels: labels never meet.
function legendSpot(index, count, cx, cy, outer, gap) {
    const all = slices(count); // a delegate may still ask for an arc just gone
    const s = all[Math.max(0, Math.min(index | 0, all.length - 1))];
    const mid = (s.start + s.end) / 2;
    const p = point(cx, cy, outer + gap, mid);
    return { "x": p.x, "y": p.y, "align": Math.abs(mid - TOP) < 1 ? "center" : mid < TOP ? "right" : "left" };
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
    const spread = 52 * (1 - 0.6 * Math.abs(pan));
    const deg = Math.max(LEFT + 3, Math.min(RIGHT - 3, TOP + pan * 87 + (u1 - 0.5) * spread));
    const dist = radius * Math.pow(a, 0.7) * (0.55 + 0.45 * u2);
    return {
        "deg": deg,
        "dist": dist,
        "size": 2 + 2.6 * u3 * (1 - band / frame.l.length * 0.45),
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

// --- Visualizer styles (scopeStyle: "points", "rays", "waves", "none") -------

function styleOf(name) {
    return ["points", "rays", "waves", "none"].indexOf(name) >= 0 ? name : "points";
}

// A frame with no band: rays and waves start from it, and fall back to it
function emptyLevels() {
    return { "l": [], "r": [] };
}

// Rays and waves lay the spectrum over the half circle: the left channel on
// the left quarter, the right one on the right, low notes at the top (where
// a centered bass sits on a scope) and high notes toward each side. The
// level (0..1) at an angle, interpolated between bands.
function levelAt(frame, deg) {
    if (!frame || !frame.l || !frame.l.length)
        return 0;
    const side = deg < TOP ? frame.l : frame.r;
    const n = side.length;
    const t = Math.max(0, Math.min(1, Math.abs(deg - TOP) / 90));
    const x = t * (n - 1);
    const i = Math.floor(x);
    const at = k => side[Math.max(0, Math.min(n - 1, k))];
    // A Catmull-Rom curve through the bands, not straight segments: the
    // outline stays round between bands instead of breaking into corners
    const f = x - i, p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    const v = 0.5 * (2 * p1 + (p2 - p0) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (3 * p1 - p0 - 3 * p2 + p3) * f * f * f);
    return clamp01(v);
}

// How loud the sound is heard (0..1): the device's own level times this
// PC's, or this PC's alone for an output with no level of its own (device
// -1). Muted anywhere, nothing is heard.
function heardLevel(device, pc, deviceMuted, pcMuted) {
    if (device < 0)
        return pcMuted ? 0 : pc;
    return deviceMuted || pcMuted ? 0 : device * pc;
}

// How big the picture is drawn at the volume the user hears: it grows and
// shrinks with the level, never quite vanishing (the sound still flows)
function scaleFor(gain) {
    return 0.22 + 0.78 * Math.sqrt(clamp01(gain));
}

// Where a ray or a wave reaches at that level: never quite at the center,
// so silence still draws a faint ring of light
function reach(level, radius) {
    return radius * (0.16 + 0.84 * Math.pow(clamp01(level), 0.7));
}

// The angles of `count` rays per side, from the top outward
function rayAngles(count) {
    const out = [];
    const n = Math.max(1, count | 0);
    for (let i = 0; i < n; i++) {
        const off = (i + 0.5) / n * 87;
        out.push(TOP - off, TOP + off);
    }
    return out;
}

// Meter ballistics: a level rises fast and falls back slowly, as on a
// studio meter, both eased over a few frames so the picture glides
// instead of jumping from one cava frame to the next
function follow(prev, target, dt) {
    const p = clamp01(prev), t = clamp01(target);
    const rate = t >= p ? 18 : 6;
    return p + (t - p) * (1 - Math.exp(-dt * rate));
}

// A value eased toward another, the same at any frame rate
function ease(prev, target, dt, rate) {
    return prev + (target - prev) * (1 - Math.exp(-dt * rate));
}
