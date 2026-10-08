.pragma library
.import "Radar.js" as Radar
.import "RadarRandom.js" as Rand

// The sky behind the radar's dials (Orbit's sky, variant C): a few faint stars
// and two nebulae, and the full circle the small dials orbit on, all kept clear of
// whatever has to be read. Pure: where the stars fall, which dashes the orbit has
// and how bright each is. RadarSky.qml only paints what is here, once per opening.
// Tested by tests/radarSky.test.js.

var SEED = 1337;      // the same sky at every opening
var TOP_GAP = 8;      // the sky starts this far under the card's header...
var FADE = 24;        // ...and fades in over this much
var DENSITY = 2500;   // one star per this many px² of sky
var MAX_STARS = 60;
var TRIES = 8;        // draws per wanted star: one that lands in a clearing is dropped
var BIG = 0.15;       // share of big stars
var TINTED = 0.2;     // share of the big ones that carry the group's color

var DASH = 2;         // px drawn...
var PERIOD = 8;       // ...every this many px along the orbit
var FLOOR = 0.12;     // the orbit's alpha away from the satellites' arc
var ARC_NEAR = 70;    // degrees from straight up where the orbit is at its brightest
var ARC_FAR = 82;     // and where it has faded to FLOOR: the satellites' arc + 12°

// Where the sky starts, from the top of the card
function top(headerHeight) {
    return headerHeight + TOP_GAP;
}

function starCount(width, bodyHeight) {
    return Math.min(MAX_STARS, Math.round(width * bodyHeight / DENSITY));
}

// What the sky keeps clear, from the radar's places (Radar.layout, `cx`, `cy` the
// hero's middle): a disc around the hero and each small dial, the strip a small
// dial's name takes under it, and the band the actions are laid out in. The band,
// not the pills on show: it does not move when the hero changes, so neither does the sky.
function clearings(places, cx, cy, width, actionsY) {
    const discs = [{ "x": cx, "y": cy, "r": places.hero.r + 8 }];
    const rects = [];
    for (const s of places.satellites) {
        discs.push({ "x": cx + s.x, "y": cy + s.y, "r": s.r + 6 });
        const w = Math.max(72, 3 * s.r);
        rects.push({ "x": cx + s.x - w / 2 - 4, "y": cy + s.y + s.r + 2 - 4, "w": w + 8, "h": 14 + 8 });
    }
    rects.push({ "x": 1 - 4, "y": actionsY - 4, "w": width - 2 + 8, "h": Radar.ACTIONS + 8 });
    return { "discs": discs, "rects": rects };
}

// Whether a point, `pad` px of margin included, is outside every clearing
function isClear(c, x, y, pad) {
    for (const d of c.discs)
        if (Math.hypot(x - d.x, y - d.y) < d.r + pad)
            return false;
    for (const r of c.rects)
        if (x > r.x - pad && x < r.x + r.w + pad && y > r.y - pad && y < r.y + r.h + pad)
            return false;
    return true;
}

// The stars of a sky `width` wide whose body runs `bodyHeight` under `skyTop`:
// [{ x, y, r, a, tinted }]. A star that falls in a clearing is dropped and another
// drawn, up to TRIES draws per star wanted.
function stars(width, skyTop, bodyHeight, c) {
    const rand = Rand.random(SEED);
    const wanted = starCount(width, bodyHeight);
    const out = [];
    for (let tries = 0; out.length < wanted && tries < wanted * TRIES; tries++) {
        const x = rand() * width;
        const y = skyTop + rand() * bodyHeight;
        const big = rand() < BIG;
        const r = big ? 0.9 + rand() * 0.5 : 0.35 + rand() * 0.5;
        const a = big ? 0.30 : 0.10 + rand() * 0.16;
        const tinted = big && rand() < TINTED;
        if (isClear(c, x, y, r))
            out.push({ "x": x, "y": y, "r": r, "a": a, "tinted": tinted });
    }
    return out;
}

// How bright the orbit is `off` degrees from straight up: full along the satellites'
// arc, fading over 12° to FLOOR, and FLOOR all the way round
function orbitAlpha(off, light) {
    const peak = light ? 0.26 : 0.22;
    if (off <= ARC_NEAR)
        return peak;
    if (off <= ARC_FAR)
        return Math.max(FLOOR, peak * (ARC_FAR - off) / (ARC_FAR - ARC_NEAR));
    return FLOOR;
}

// The dashes of an orbit of radius `radius` around (cx, cy), from -180° to 180°,
// grouped by alpha so the painter strokes each group as one path:
// [{ a, spans: [[from, to]] }] with angles in radians. A dash whose middle is in a
// clearing is left out: the ring passes behind the dials, names and actions.
function dashes(radius, cx, cy, light, c) {
    const step = PERIOD / radius, length = DASH / radius;
    const groups = new Map();
    for (let t = -Math.PI; t < Math.PI; t += step) {
        const mid = t + length / 2;
        if (!isClear(c, cx + Math.cos(mid) * radius, cy + Math.sin(mid) * radius, 0))
            continue;
        // Degrees from straight up (-90°), the short way round
        const away = ((mid * 180 / Math.PI + 90) % 360 + 360) % 360;
        const off = away > 180 ? 360 - away : away;
        const a = Math.round(orbitAlpha(off, light) * 1000) / 1000;
        if (!groups.has(a))
            groups.set(a, []);
        groups.get(a).push([t, t + length]);
    }
    return Array.from(groups, ([a, spans]) => ({ "a": a, "spans": spans }));
}
