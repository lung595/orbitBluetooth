.pragma library

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

// Where a pointer at (x, y) sets the ring around the centre (0 at the top,
// clockwise, 0..1), moved the short way from `last` so that crossing the top
// does not jump from one end to the other
function fromPointer(cx, cy, x, y, last) {
    let v = (Math.atan2(y - cy, x - cx) + Math.PI / 2) / (Math.PI * 2);
    v = v - Math.floor(v);
    if (last > 0.75 && v < 0.25)
        return 1;
    if (last < 0.25 && v > 0.75)
        return 0;
    return v;
}
