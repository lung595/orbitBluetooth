.pragma library

// Pure logic of the volume ring (VolumeRing.qml), tested in tests/volume.test.js.

// The ring is open at the bottom (where the glyph meets the card): it starts
// at bottom-left and runs clockwise over the top to bottom-right.
// Angles in degrees, clockwise from 3 o'clock, as PathAngleArc wants them.
var start = 120;
var sweep = 300;

// One wheel notch
var stepSize = 0.05;

function clamp(v) {
    return Math.max(0, Math.min(1, Number(v) || 0));
}

// Index of the 5 % step a level falls in: a tick plays when it changes
function step(v) {
    return Math.round(clamp(v) / stepSize);
}

// Wheel: whole 5 % steps from the current level, landing on the grid
function nudge(v, steps) {
    return clamp((step(v) + steps) * stepSize);
}

// Level under the pointer at (dx, dy) from the center. In the gap at the
// bottom it stays at the nearest end (from the current level), so a drag
// never jumps from 100 % to 0 % across it.
function valueAt(dx, dy, current) {
    let a = Math.atan2(dy, dx) * 180 / Math.PI;
    let rel = ((a - start) % 360 + 360) % 360;
    if (rel > sweep)
        return clamp(current) >= 0.5 ? 1 : 0;
    return clamp(rel / sweep);
}

// What the pointer is over: "ring" (a band around the ring, wide enough to
// grab), "glyph" (the device, click = mute) or "" (nothing of ours)
function zone(dx, dy, radius, glyphRadius) {
    const d = Math.sqrt(dx * dx + dy * dy);
    if (Math.abs(d - radius) <= 14)
        return "ring";
    if (d < Math.min(glyphRadius, radius - 14))
        return "glyph";
    return "";
}

// The device's output sink. Its name carries the Bluetooth address with
// underscores (bluez_output.AA_BB_CC_DD_EE_FF.1).
function findSink(nodes, address) {
    if (!address || !nodes)
        return null;
    const needle = String(address).replace(/:/g, "_").toLowerCase();
    if (!/^([0-9a-f]{2}_){5}[0-9a-f]{2}$/.test(needle))
        return null;
    for (let i = 0; i < nodes.length; i++) {
        const n = nodes[i];
        if (n && n.isSink && !n.isStream && n.name && n.name.toLowerCase().indexOf(needle) >= 0)
            return n;
    }
    return null;
}

// Only a plain node name is ever passed to pw-play (value 11)
function validSink(name) {
    return typeof name === "string" && name.length > 0 && name.length <= 128 && /^[A-Za-z0-9_.:-]+$/.test(name);
}
