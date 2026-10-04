.pragma library
.import "../common/Palette.js" as Palette

// The colours of the outputs listening together and of this PC's shared
// level (D277), all from the theme: each output takes one of the theme's
// accents (primary, secondary, tertiary, in that order), this PC's the
// tertiary. An accent that passes for one already taken (hues less than a
// fraction of a turn apart, or a grey) is turned to the hue farthest from
// every colour taken, keeping its own saturation and lightness, so a
// palette stays itself and stays readable. Colours are {r, g, b} in 0..1.

// How far apart two hues are, in turns (0..0.5)
function _gap(a, b) {
    const d = Math.abs(a - b);
    return Math.min(d, 1 - d);
}

// The hue farthest from every hue in `taken`, the nearer to `own` on a tie
function _farthest(taken, own) {
    let best = own, bestGap = -1, bestNear = 1;
    for (let k = 0; k < 24; k++) {
        const h = k / 24;
        const gap = Math.min(...taken.map(t => _gap(h, t)));
        const near = _gap(h, own);
        if (gap > bestGap + 1e-9 || (Math.abs(gap - bestGap) <= 1e-9 && near < bestNear)) {
            best = h;
            bestGap = gap;
            bestNear = near;
        }
    }
    return best;
}

// `bases`: the theme's accents [primary, secondary, tertiary]. `count`
// outputs (1..4) then this PC: count + 1 colours, this PC's last.
function pick(bases, count) {
    const total = Math.max(1, Math.min(4, count | 0)) + 1;
    const minGap = Math.min(0.25, 0.75 / total);
    const out = [];
    const hues = [];
    for (let k = 0; k < total; k++) {
        const base = bases[k === total - 1 ? 2 : k % 3];
        const hsl = Palette.toHsl(base);
        const plain = !Palette.isGrey(base);
        if (k === 0 || (plain && hues.every(h => _gap(h, hsl.h) >= minGap))) {
            out.push({ "r": base.r, "g": base.g, "b": base.b });
            if (plain)
                hues.push(hsl.h);
            continue;
        }
        // A grey accent has no hue of its own: borrow the first colour's
        // saturation so the turned colour is not grey as well
        const sat = plain ? hsl.s : Math.max(0.4, Palette.toHsl(out[0]).s);
        const h = _farthest(hues.length ? hues : [0], hsl.h);
        out.push(Palette.fromHsl(h, sat, hsl.l));
        hues.push(h);
    }
    return out;
}
