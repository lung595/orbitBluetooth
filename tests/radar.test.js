// The volume radar's maths: where the hero and the satellites sit, how a point on a dial is a level, the hero's actions.
// Run from the plugin root: gjs tests/radar.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const R = load("Radar.js", ["STYLES", "START", "SWEEP", "styleOf", "layout", "angleOf", "levelAt", "percent", "heroOf", "around", "chips"]);

const near = v => Math.round(v * 1000) / 1000;
const side = 300;

// --- the layout ---------------------------------------------------------------
eq("style: the hero look is the only one now, and what is not known is it", [R.styleOf("hero"), R.styleOf("rings"), R.styleOf(undefined)], ["hero", "hero", "hero"]);
eq("layout: the hero sits in the middle and is the biggest dial", [R.layout("hero", 3, side).hero.x, R.layout("hero", 3, side).hero.y, R.layout("hero", 3, side).hero.r > R.layout("hero", 3, side).satellites[0].r * 2], [0, 0, true]);
eq("layout: one satellite per dial around the hero, none for a hero alone", [0, 1, 2, 3, 4, 5].map(n => R.layout("hero", n, side).satellites.length), [0, 1, 2, 3, 4, 5]);
eq("layout: a lone satellite is straight above the hero", [near(R.layout("hero", 1, side).satellites[0].x), R.layout("hero", 1, side).satellites[0].y < 0], [0, true]);
const spread = n => R.layout("hero", n, side).satellites;
eq("layout: they run left to right along the upper side, never below the hero's middle", [2, 3, 4, 5].map(n => spread(n).every((s, i) => s.y < 0 && (i === 0 || s.x > spread(n)[i - 1].x))), [true, true, true, true]);
eq("layout: they are centred on the hero's axis", [2, 3, 4, 5].map(n => near(spread(n)[0].x + spread(n)[n - 1].x)), [0, 0, 0, 0]);
const apart = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
eq("layout: two satellites never touch, up to the group and four members", [2, 3, 4, 5].map(n => spread(n).every((s, i) => i === 0 || apart(s, spread(n)[i - 1]) > s.r * 2.2)), [true, true, true, true]);
eq("layout: none touches the hero", [1, 3, 5].map(n => spread(n).every(s => Math.hypot(s.x, s.y) - s.r > R.layout("hero", n, side).hero.r)), [true, true, true]);
const reach = n => Math.max(...spread(n).map(s => Math.hypot(s.x, s.y) + s.r));
eq("layout: all of it fits the radar's side", [1, 5].map(n => reach(n) < side / 2), [true, true]);
eq("layout: it scales with the side", near(R.layout("hero", 3, 2 * side).satellites[1].y / R.layout("hero", 3, side).satellites[1].y), 2);

// --- a point on a dial is a level ----------------------------------------------
eq("gauge: it opens at the bottom, 270 degrees from 7:30", [R.START, R.SWEEP], [135, 270]);
eq("gauge: the angle of a level, held to the ends", [R.angleOf(0), R.angleOf(0.5), R.angleOf(1), R.angleOf(-3), R.angleOf(4)], [135, 270, 405, 135, 405]);
eq("point: left, top and right of the dial", [near(R.levelAt(-1, 0)), near(R.levelAt(0, -1)), near(R.levelAt(1, 0))], [near(45 / 270), 0.5, near(225 / 270)]);
eq("point: both ends of the gauge", [near(R.levelAt(-1, 1)), near(R.levelAt(1, 1))], [0, 1]);
eq("point: in the opening at the bottom it goes to the nearer end", [R.levelAt(-0.2, 1), R.levelAt(0.2, 1)], [0, 1]);
eq("point: the angle of a level gives that level back", [0.1, 0.25, 0.5, 0.75, 0.9].map(l => near(R.levelAt(Math.cos(R.angleOf(l) * Math.PI / 180), Math.sin(R.angleOf(l) * Math.PI / 180)))), [0.1, 0.25, 0.5, 0.75, 0.9]);
eq("percent: whole percents, held to 0..100", [R.percent(0.624), R.percent(0.625), R.percent(1.4), R.percent(-1)], [62, 63, 100, 0]);

// --- the hero and what can be done with it ---------------------------------------
const ids = ["group", "aa", "bb", "cc"];
eq("hero: the one asked for, else the group's", [R.heroOf(ids, "bb"), R.heroOf(ids, "zz"), R.heroOf(ids, ""), R.heroOf([], "x")], ["bb", "group", "group", ""]);
eq("around: every dial but the hero, in order", [R.around(ids, "group"), R.around(ids, "bb")], [["aa", "bb", "cc"], ["group", "aa", "cc"]]);
const labels = kind => R.chips(kind).map(c => c.label);
eq("chips: a Bluetooth member", labels("bluetooth"), ["Disconnect", "Remove from group", "Hide", "Details"]);
eq("chips: a wired member has no details and no Bluetooth to disconnect, its Disconnect takes it out of the group", [labels("wired"), R.chips("wired")[0].id], [["Disconnect", "Hide"], "disconnect"]);
eq("chips: the group adds a device or stops, and stopping is the one in red", [labels("group"), R.chips("group").map(c => !!c.danger)], [["Add a device…", "Stop group"], [false, true]]);
eq("chips: every one has an id, an icon and a label", ["group", "bluetooth", "wired"].every(k => R.chips(k).every(c => c.id && c.icon && c.label)), true);

done();
