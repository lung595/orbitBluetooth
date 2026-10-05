.pragma library
.import "../together/Member.js" as Member
.import "../together/Wired.js" as Wired

// How a wired member looks inside a Listen together (D298): a rounded square
// where a Bluetooth device is a round disc, its own picture by kind of output,
// and a cable to the source that goes taut as the output joins. Pure: the QML
// only reads it. Tested by tests/wiredsign.test.js.

// The square's corner as a share of its side (a circle would be 0.5): soft, yet
// clearly not a Bluetooth disc
var CORNER = 0.3;
// How long the cable takes to go taut when the output joins (ms)
var TIGHTEN = 400;
// How far a loose cable hangs below its line, as a share of its length
var SLACK = 0.18;

// The picture of a wired member: "usb", "hdmi", "analog" or "other" (Wired.kindOf),
// from its node name and the node's properties (device.bus, device.form_factor),
// which may be missing
function kindOf(sink, properties) {
    const p = properties && typeof properties === "object" ? properties : {};
    return Wired.kindOf({ "sink": sink, "bus": p["device.bus"], "formFactor": p["device.form_factor"] });
}

// Is the point (dx, dy), measured from the square's centre, inside the rounded
// square of side `side`? The click zone of a wired disc is the shape it is drawn
// with, not the box around it.
function inside(dx, dy, side) {
    const half = side / 2, corner = Math.min(half, CORNER * side);
    const x = Math.abs(dx), y = Math.abs(dy);
    // Written so that a missing number (NaN) is outside too
    if (!(x <= half && y <= half))
        return false;
    // Past the straight part of both sides, only the corner's quarter circle counts
    const cx = x - (half - corner), cy = y - (half - corner);
    return cx <= 0 || cy <= 0 || cx * cx + cy * cy <= corner * corner;
}

// How far below the straight line the cable's control point hangs (px) at a
// `tension` from 0 (loose) to 1 (taut). A quadratic curve only reaches half of
// its control point's offset, hence the 2.
function drop(length, tension) {
    const t = Math.max(0, Math.min(1, tension));
    return 2 * SLACK * Math.max(0, length) * (1 - t);
}

// The point at `t` (0..1) along the cable from a to b ({ x, y }) when its control
// point hangs `drop` below the middle: where the pulse travelling along it is
function along(a, b, t, drop) {
    return { "x": a.x + (b.x - a.x) * t, "y": a.y + (b.y - a.y) * t + 2 * t * (1 - t) * drop };
}

// The change that brings the rows of the wired discs to the wired members of
// the group: { remove: row numbers, last first, add: tokens, in order }. A row
// that stays is not touched, so its disc keeps its cable and its one-time
// animations while the others come and go.
function reconcile(rows, members) {
    const have = Array.isArray(rows) ? rows : [];
    const wanted = (Array.isArray(members) ? members : []).filter((token, i, all) => Member.isWired(token) && all.indexOf(token) === i);
    const remove = [];
    have.forEach((token, i) => {
        if (wanted.indexOf(token) < 0)
            remove.unshift(i);
    });
    return { "remove": remove, "add": wanted.filter(token => have.indexOf(token) < 0) };
}
