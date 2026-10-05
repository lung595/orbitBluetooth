.pragma library

// The shape of the volume gauge around the group's source (D295): an open arc
// of 270 degrees whose gap is at the bottom, where the members' row sits. It
// starts at the bottom left (the speaker) and runs clockwise over the top to the
// bottom right. Angles are QML's: degrees from 3 o'clock, clockwise (y points
// down). Pure functions of the geometry: LevelGauge draws them and the pointer
// reads them back (MasterVolume.fromPointer); tested by tests/gauge.test.js.

var START = 135;                    // degrees: the arc's start, bottom left
var SWEEP = 270;                    // degrees the arc spans, the rest is the gap
var TICKS = 10;                     // marks every 10 %, longer at 0, 50 and 100
var SLOP = 8;                       // degrees past each end a press still counts (the round caps)

function clamp01(v) {
    return Math.max(0, Math.min(1, v));
}

// Angle (radians) of level `v` (0..1) on the gauge
function angleOf(v) {
    return (START + SWEEP * clamp01(v)) * Math.PI / 180;
}

// The point of level `v` on the circle of radius `r` around (cx, cy)
function pointAt(cx, cy, r, v) {
    const a = angleOf(v);
    return { "x": cx + Math.cos(a) * r, "y": cy + Math.sin(a) * r };
}

// Length (px) of the arc from its start to level `v`, `r` px from the centre
function length(v, r) {
    return clamp01(v) * SWEEP * Math.PI / 180 * r;
}

// Degrees clockwise from the arc's start to a pointer at (x, y): 0..360, the
// gap being what is past SWEEP
function turn(cx, cy, x, y) {
    const deg = Math.atan2(y - cy, x - cx) * 180 / Math.PI - START;
    return ((deg % 360) + 360) % 360;
}

// Whether a pointer at (x, y) is on the band of the gauge: within `band` px of
// its circle and between its two ends, never in the gap, which belongs to what
// sits under the gauge
function hit(cx, cy, x, y, radius, band) {
    if (Math.abs(Math.hypot(x - cx, y - cy) - radius) > band)
        return false;
    const t = turn(cx, cy, x, y);
    return t <= SWEEP + SLOP || t >= 360 - SLOP;
}

const p = pt => Math.round(pt.x * 100) / 100 + " " + Math.round(pt.y * 100) / 100;

// The outline of the band of width `w` around the circle of radius `r`, from
// level v0 to v1, with round ends, as SVG path data (a fill, so that it can
// take a gradient: a stroke cannot)
function band(cx, cy, r, w, v0, v1) {
    const c = w / 2;
    const big = SWEEP * (v1 - v0) > 180 ? 1 : 0;
    const outerStart = pointAt(cx, cy, r + c, v0);
    const outerEnd = pointAt(cx, cy, r + c, v1);
    const innerEnd = pointAt(cx, cy, r - c, v1);
    const innerStart = pointAt(cx, cy, r - c, v0);
    return "M " + p(outerStart) + " A " + (r + c) + " " + (r + c) + " 0 " + big + " 1 " + p(outerEnd)
        + " A " + c + " " + c + " 0 0 1 " + p(innerEnd)
        + " A " + (r - c) + " " + (r - c) + " 0 " + big + " 0 " + p(innerStart)
        + " A " + c + " " + c + " 0 0 1 " + p(outerStart) + " Z";
}

// The marks that the level has reached (`lit`) or not yet, as SVG path data,
// each `size` px long from `from` px out of the centre; the ones at 0, 50 and
// 100 % are longer. Empty when there are none.
function ticks(cx, cy, from, size, level, lit) {
    let path = "";
    for (let i = 0; i <= TICKS; i++) {
        const v = i / TICKS;
        if ((v <= level + 1e-9) !== lit)
            continue;
        const reach = i % 5 === 0 ? 1.7 : 1;
        path += "M " + p(pointAt(cx, cy, from, v)) + " L " + p(pointAt(cx, cy, from + size * reach, v)) + " ";
    }
    return path;
}
