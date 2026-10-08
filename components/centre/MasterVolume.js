.pragma library
.import "Gauge.js" as Gauge

// The general volume of a Listen together (D284): one master that moves every
// member and keeps the gaps between them (general 50 % to 80 %: a member at
// 40 % goes to 64 %, one at 30 % to 48 %). Levels are fractions, 0..1. Each
// member keeps its own level too, and moving one never moves the others.

// The general level when the members have no shared one: the loudest, so that
// the master can always reach 100 % without anyone passing it
function general(levels) {
    return levels.reduce((top, v) => Math.max(top, v), 0);
}

// The highest the master may go from `from` before the loudest member would
// pass 100 %: past it the gaps could not be kept
function ceiling(levels, from) {
    const top = general(levels);
    return top > 0 && from > 0 ? from / top : 1;
}

// The members' levels once the master goes from `from` to `to`: every level is
// multiplied by the same ratio. With nothing to scale (all silent) they all go
// to `to`, there are no gaps to keep.
function scale(levels, from, to) {
    const target = Math.max(0, Math.min(to, ceiling(levels, from)));
    if (!(from > 0))
        return levels.map(() => target);
    return levels.map(v => Math.max(0, Math.min(1, v * target / from)));
}

// Where a pointer at (x, y) sets the gauge around (cx, cy): 0 at its start
// (bottom left), 1 at its end (bottom right), the level held at both ends and
// never wrapping. In the gap at the bottom it takes the end the pointer is
// nearer to on a fresh press (`last` empty), and the end it came from while it
// is held (`last` the level it read before), so crossing the gap does not jump.
function fromPointer(cx, cy, x, y, last) {
    const t = Gauge.turn(cx, cy, x, y);
    if (t <= Gauge.SWEEP)
        return t / Gauge.SWEEP;
    if (last >= 0)
        return last >= 0.5 ? 1 : 0;
    return t - Gauge.SWEEP < (360 - Gauge.SWEEP) / 2 ? 1 : 0;
}

// The speaker that goes with the general level: crossed out when the group is
// muted, empty at zero, then one wave and two (Material's glyph names)
function icon(level, muted) {
    if (muted)
        return "volume_off";
    return level > 0 ? (level < 0.5 ? "volume_down" : "volume_up") : "volume_mute";
}
