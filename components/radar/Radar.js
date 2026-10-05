.pragma library

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
var HERO = 0.22;      // the hero's radius, of the radar's side
var SATELLITE = 0.085;
var ORBIT = 0.4;      // the satellites' ring, of the side, from the hero's middle
var SPREAD = 50;      // degrees between two satellites at most
var ARC = 140;        // degrees they cover at most: the upper side, the hero's name and the chips stay clear

function styleOf(name) {
    return STYLES.indexOf(name) >= 0 ? name : STYLES[0];
}

// Where the hero and `count` satellites sit in a radar `side` px wide, from its
// middle: { hero: {x, y, r}, satellites: [{x, y, r}] }. The satellites run along
// the upper arc, left to right.
function layout(style, count, side) {
    const n = Math.max(0, count | 0);
    const step = n > 1 ? Math.min(SPREAD, ARC / (n - 1)) : 0;
    const satellites = [];
    for (let i = 0; i < n; i++) {
        const a = (-90 + (i - (n - 1) / 2) * step) * Math.PI / 180;
        satellites.push({ "x": Math.cos(a) * ORBIT * side, "y": Math.sin(a) * ORBIT * side, "r": SATELLITE * side });
    }
    return { "hero": { "x": 0, "y": 0, "r": HERO * side }, "satellites": satellites };
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
