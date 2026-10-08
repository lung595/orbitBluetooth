.pragma library
.import "RadarRandom.js" as Rand

// The volume radar of a Listen together: one level is the hero, drawn big (the
// group's, or the member that was clicked), and every other level stays around
// it as a small dial within reach. Pure: where each dial sits, how a point on a
// dial's ring is a level, which actions go with the hero. The QML only draws
// what is here. Tested by tests/radar.test.js.

// The looks the radar can have: "hero" is the one drawn now, the others come
// with the setting; an unknown name is the hero look
var STYLES = ["hero"];

var START = 135;      // where a dial's gauge starts, in degrees clockwise from 3 o'clock (7:30)
var SWEEP = 270;      // how far it runs, so it opens at the bottom, where the mute badge sits
var HERO = 0.2;       // the hero's radius, of the radar's side
var SATELLITE = 0.085;
var ORBIT = 0.44;     // the satellites' ring, of the side, from the hero's middle
var SPREAD = 50;      // degrees between two satellites at most
var ARC = 140;        // degrees they cover at most: the upper side, the hero's name and the chips stay clear

// Every dial sits a little off its ideal place, still and uneven, as if it
// weighed nothing: no motion, so no cost while the radar is open.
var DRIFT = 0.018;       // a satellite's largest offset along the orbit, of the side
var HERO_DRIFT = 0.008;  // the hero's largest offset, of the side: under half a satellite's
var NAME_GAP = 4;        // how little two names may be apart at least, when they were that far without the offset

function styleOf(name) {
    return STYLES.indexOf(name) >= 0 ? name : STYLES[0];
}

// Where the hero and `count` satellites sit in a radar `side` px wide, from its
// middle: { hero: {x, y, r}, satellites: [{x, y, r}] }. The satellites run along
// the upper arc, left to right. The offsets come from the rank of a place, never
// from the device, so a new hero moves no dial's place (and so no clearing of the sky).
function layout(style, count, side) {
    const n = Math.max(0, count | 0);
    const spots = amp => places(n, side, amp);
    // Halve the offset, then drop it, until no two names come closer than they did
    const plain = spots(0);
    const amp = [1, 0.5].find(k => namesKept(plain, spots(k))) ?? 0;
    return { "hero": heroSpot(n, side), "satellites": spots(amp) };
}

// The satellites with their offset scaled by `k` (0 = on the orbit)
function places(n, side, k) {
    const step = n > 1 ? Math.min(SPREAD, ARC / (n - 1)) : 0;
    const out = [];
    for (let i = 0; i < n; i++) {
        const a = (-90 + (i - (n - 1) / 2) * step) * Math.PI / 180;
        const u = Rand.random(7919 * n + 104729 * (i + 1))();
        const d = k * (i % 2 ? -1 : 1) * DRIFT * side * (0.55 + 0.45 * u);
        const reach = ORBIT * side + d;
        out.push({ "x": Math.cos(a) * reach, "y": Math.sin(a) * reach, "r": SATELLITE * side });
    }
    return out;
}

function heroSpot(n, side) {
    const next = Rand.random(7919 * n);
    const d = HERO_DRIFT * side * (0.6 + 0.4 * next());
    const a = 2 * Math.PI * next();
    return { "x": Math.cos(a) * d, "y": Math.sin(a) * d, "r": HERO * side };
}

// The room between two satellites' names (each `max(72, 3r)` wide and 14 high,
// right under its dial), 0 when they touch; negative when they overlap
function nameGap(a, b) {
    const w = Math.max(72, 3 * a.r);
    return Math.max(Math.abs(a.x - b.x) - w, Math.abs(a.y - b.y) - 14);
}

// Whether the moved satellites keep every pair of names as far apart as the
// ideal ones, up to NAME_GAP
function namesKept(ideal, moved) {
    return moved.every((s, i) => i === 0 || nameGap(s, moved[i - 1]) >= Math.min(nameGap(ideal[i], ideal[i - 1]), NAME_GAP));
}

var PILL = 30;        // the height of one action
var GAP = 8;          // between two actions, and between two rows of them
var PER_ROW = 2;      // how many fit side by side in a card: a Bluetooth member has four
var ACTIONS = PILL * 2 + GAP;   // the room the actions take, two rows for every hero so the card keeps its size when the hero changes
var UNDER = 14;       // the gap between the hero's ring and its actions
var SHARE = 0.92;     // how much of the card's inner width the radar's side takes

// The room the dials take in a radar `side` px wide, from the hero's middle:
// up to the top of the highest small dial, and down to the end of the actions.
// Everything scales with the side but the gap and the actions row.
function extent(style, count, side) {
    const spots = layout(style, count, side);
    return {
        "above": Math.max(spots.hero.r - spots.hero.y, ...spots.satellites.map(s => s.r - s.y)),
        "below": spots.hero.r + UNDER + ACTIONS
    };
}

// The side that fits a card `width` px wide and `room` px high for the dials and
// the actions: the widest there is room for, never less than `MIN_SIDE`
var MIN_SIDE = 120;
function sideFor(style, count, width, room) {
    const wide = Math.max(MIN_SIDE, width * SHARE);
    const e = extent(style, count, wide);
    const fixed = UNDER + ACTIONS;
    const perPx = (e.above + e.below - fixed) / wide;
    return Math.max(MIN_SIDE, Math.min(wide, (room - fixed) / perPx));
}

// The height the dials and actions take at the widest side, for a card `width` px wide
function blockHeight(style, count, width) {
    const e = extent(style, count, Math.max(MIN_SIDE, width * SHARE));
    return e.above + e.below;
}

// The angle of a level on the gauge (degrees clockwise from 3 o'clock)
function angleOf(level) {
    return START + SWEEP * Math.max(0, Math.min(1, level));
}

// The level of a point `dx`, `dy` from a dial's middle (y down). A point in the
// opening at the bottom goes to the nearer end, so a drag may run past it.
function levelAt(dx, dy) {
    const a = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360;
    const along = (a - START + 360) % 360;
    if (along > SWEEP)
        return along - SWEEP > (360 - SWEEP) / 2 ? 0 : 1;
    return along / SWEEP;
}

function percent(level) {
    return Math.round(Math.max(0, Math.min(1, level)) * 100);
}

// The hero among the dials' ids: the one asked for when it is there, else the
// group's (the first)
function heroOf(ids, want) {
    return ids.indexOf(want) >= 0 ? want : (ids[0] ?? "");
}

// The dials around the hero, in the order of the group
function around(ids, hero) {
    return ids.filter(id => id !== hero);
}

// The line under the hero's name in the card's header: what it is, and for the
// group how many outputs share the sound
function subtitle(kind, outputs) {
    if (kind === "group")
        return "Group · " + outputs + (outputs === 1 ? " output" : " outputs");
    return kind === "wired" ? "Wired" : "Bluetooth";
}

// What can be done with the hero, as { id, icon, label, danger }, by what it is:
// "group", a "bluetooth" member or a "wired" one. A wired output cannot be
// disconnected, so its Disconnect takes it out of the group and leaves it plugged in.
function chips(kind) {
    if (kind === "group")
        return [
            { "id": "add", "icon": "group_add", "label": "Add a device…" },
            { "id": "stop", "icon": "call_split", "label": "Stop group", "danger": true }
        ];
    const hide = { "id": "hide", "icon": "visibility_off", "label": "Hide" };
    const off = { "id": "disconnect", "icon": "link_off", "label": "Disconnect" };
    if (kind === "wired")
        return [off, hide];
    return [off, { "id": "leave", "icon": "logout", "label": "Remove from group" }, hide, { "id": "details", "icon": "info", "label": "Details" }];
}

// The hero's actions in rows of at most PER_ROW, as the card lays them out
function chipRows(kind) {
    const all = chips(kind);
    const rows = [];
    for (let i = 0; i < all.length; i += PER_ROW)
        rows.push(all.slice(i, i + PER_ROW));
    return rows;
}
