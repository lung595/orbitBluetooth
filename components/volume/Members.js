.pragma library
.import "Polar.js" as Polar

// The levels of several outputs listening together (D254, D277), and what
// the scope does with them (PolarScope, TwoLevels): pure, tested in
// tests/*.test.js. A member is { level, muted } with the level 0..1.

// How loud the sound is heard (0..1) when outputs share it: the loudest
// one's level times this PC's, a muted one silent. An empty list is this
// PC's alone.
function heardOf(list, pc, pcMuted) {
    if (!list.length)
        return Polar.heardLevel(-1, pc, false, pcMuted);
    return Math.max(...list.map(m => Polar.heardLevel(m.level, pc, m.muted, pcMuted)));
}

// How big each output's part of the picture is drawn next to the loudest
// one's (which is 1), from the volume each is heard at
function scales(heards) {
    const top = Polar.scaleFor(Math.max(0, ...heards));
    return heards.map(h => Polar.scaleFor(h) / top);
}

// The size at a place along the half circle (0 at the left end, 1 at the
// right) from each part's own size: they blend from one part's middle to the
// next one's, so the picture has no step where two outputs meet
function scaleAt(parts, place) {
    const n = parts.length;
    if (n < 2)
        return n ? parts[0] : 1;
    const x = Math.max(0, Math.min(n - 1, place * n - 0.5));
    const i = Math.floor(x);
    return parts[i] + (parts[Math.min(n - 1, i + 1)] - parts[i]) * (x - i);
}

// The levels shown, each eased toward its target on the same clock. A level
// with no shown value yet (an output just joined) starts at its target.
function easeAll(shown, targets, dt, rate) {
    return targets.map((t, i) => i < shown.length ? Polar.ease(shown[i], t, dt, rate) : t);
}

// Every shown level has reached its target, and there are as many
function settled(shown, targets, tolerance) {
    return shown.length === targets.length && targets.every((t, i) => Math.abs(shown[i] - t) < tolerance);
}
