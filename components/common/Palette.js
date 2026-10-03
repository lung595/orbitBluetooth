.pragma library

// Colour helpers, so Orbit looks right with any DMS palette: a theme's
// accent can be too pale for a light surface (pastels) or too dark for a
// dark one (deep blues), and two accents can be near twins.
// Colours are {r, g, b} in 0..1 (a QML color works as input).
// Contrast follows WCAG 2.x relative luminance.

function _lin(v) {
    return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

function luminance(c) {
    return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
}

function contrast(a, b) {
    const la = luminance(a), lb = luminance(b);
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

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

// The same hue, moved away from the background's lightness until it reaches
// the wanted contrast (it keeps its saturation, so a palette stays itself)
function ensureContrast(c, bg, ratio) {
    if (contrast(c, bg) >= ratio)
        return { r: c.r, g: c.g, b: c.b };
    const hsl = toHsl(c);
    const up = luminance(bg) < 0.4;
    let out = { r: c.r, g: c.g, b: c.b };
    for (let i = 1; i <= 40; i++) {
        const l = Math.max(0, Math.min(1, hsl.l + (up ? 1 : -1) * i * 0.025));
        out = fromHsl(hsl.h, hsl.s, l);
        if (contrast(out, bg) >= ratio || l === 0 || l === 1)
            break;
    }
    return out;
}

// The same hue and saturation at least this light: how Orbit turns a light
// theme's dark accent into one that glows on the night (NightColors.night)
function lift(c, minLightness) {
    const hsl = toHsl(c);
    return fromHsl(hsl.h, hsl.s, Math.max(hsl.l, minLightness));
}

// Ink for text on an accent fill: a deep or a pale shade of the accent's
// own hue, whichever reads better
function onColor(c) {
    const hsl = toHsl(c);
    const dark = fromHsl(hsl.h, Math.min(hsl.s, 0.5), 0.12);
    const light = fromHsl(hsl.h, Math.min(hsl.s, 0.3), 0.97);
    return contrast(dark, c) >= contrast(light, c) ? dark : light;
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
