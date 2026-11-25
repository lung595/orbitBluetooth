.pragma library

// Colour helpers, so Orbit looks right with any DMS palette: two of a
// theme's accents can be near twins.
// Colours are {r, g, b} in 0..1 (a QML color works as input).

function toHsl(c) {
    const max = Math.max(c.r, c.g, c.b), min = Math.min(c.r, c.g, c.b);
    const l = (max + min) / 2;
    if (max === min)
        return { h: 0, s: 0, l: l };
    const d = max - min;
    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    let h;
    if (max === c.r)
        h = (c.g - c.b) / d + (c.g < c.b ? 6 : 0);
    else if (max === c.g)
        h = (c.b - c.r) / d + 2;
    else
        h = (c.r - c.g) / d + 4;
    return { h: h / 6, s: s, l: l };
}

function fromHsl(h, s, l) {
    if (s === 0)
        return { r: l, g: l, b: l };
    const hue = (p, q, t) => {
        t = (t + 1) % 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    };
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    return { r: hue(p, q, h + 1 / 3), g: hue(p, q, h), b: hue(p, q, h - 1 / 3) };
}

// A colour without hue reads as grey: its glow then borrows the accent
function isGrey(c) {
    return toHsl(c).s < 0.12;
}

// A second accent that never passes for the first (D270): when its hue is
// within a quarter turn of `from`'s, it takes the opposite hue and keeps
// its own saturation and lightness, so a pink and a salmon become a pink
// and a mint. Far enough apart, or grey on either side, it stays as it is
function apart(c, from) {
    const a = toHsl(c), b = toHsl(from);
    const d = Math.abs(a.h - b.h);
    if (isGrey(c) || isGrey(from) || Math.min(d, 1 - d) >= 0.25)
        return { r: c.r, g: c.g, b: c.b };
    return fromHsl((b.h + 0.5) % 1, a.s, a.l);
}
