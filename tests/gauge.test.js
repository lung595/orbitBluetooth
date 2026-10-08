// The volume gauge's geometry (D295): a 270-degree arc with its gap at the bottom, the outline of its band, its
// tick marks and where the pointer may grab it. Run from the plugin root: gjs tests/gauge.test.js
// (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const G = load("Gauge.js");

const near = v => Math.round(v * 1000) / 1000;
const at = (v, r = 10) => G.pointAt(0, 0, r, v);
const xy = (v, r) => Object.values(at(v, r));
const rounded = pt => [Math.round(pt.x * 100) / 100, Math.round(pt.y * 100) / 100];

eq("gauge: it starts at the bottom left, goes over the top and ends at the bottom right", [rounded(at(0)), rounded(at(0.5)), rounded(at(1))], [[-7.07, 7.07], [0, -10], [7.07, 7.07]]);
eq("gauge: a level past either end is held there", [G.angleOf(-1), G.angleOf(2)], [G.angleOf(0), G.angleOf(1)]);
eq("gauge: the arc is three quarters of the circle", near(G.length(1, 10) / (2 * Math.PI * 10)), 0.75);
eq("gauge: its length is 0 at the start and held at the end", [G.length(0, 10), near(G.length(3, 10) - G.length(1, 10))], [0, 0]);
eq("turn: degrees clockwise from the start, the gap past 270", [near(G.turn(0, 0, -7.07, 7.07)), near(G.turn(0, 0, 0, -10)), near(G.turn(0, 0, 0, 10))], [0, 135, 315]);

// What a press may grab: the band along the arc, a little past its ends, never the gap or what is off the band
eq("hit: on the band, on the arc", [G.hit(0, 0, ...xy(0.5, 56), 56, 12), G.hit(0, 0, ...xy(0.5, 66), 56, 12), G.hit(0, 0, ...xy(0.5, 46), 56, 12)], [true, true, true]);
eq("hit: off the band", [G.hit(0, 0, ...xy(0.5, 30), 56, 12), G.hit(0, 0, ...xy(0.5, 80), 56, 12)], [false, false]);
eq("hit: not in the gap at the bottom, whatever the radius", [G.hit(0, 0, 0, 56, 56, 12), G.hit(0, 0, 0, 62, 56, 12)], [false, false]);
// The point `t` degrees clockwise from the arc's start, 56 px from the centre (t past 270 is in the gap)
const turned = t => [Math.cos((135 + t) * Math.PI / 180) * 56, Math.sin((135 + t) * Math.PI / 180) * 56];
eq("hit: a little past each end still counts, further does not", [G.hit(0, 0, ...turned(-5), 56, 12), G.hit(0, 0, ...turned(275), 56, 12), G.hit(0, 0, ...turned(-20), 56, 12), G.hit(0, 0, ...turned(290), 56, 12)], [true, true, false, false]);

// The band's outline: a closed path in SVG data, the big-arc flag set past half a turn
const full = G.band(100, 100, 50, 5, 0, 1);
eq("band: a closed outline made of two arcs and two caps", [full.startsWith("M "), full.endsWith(" Z"), full.split(" A ").length - 1], [true, true, 4]);
eq("band: more than half a turn takes the large arc, less does not", [G.band(0, 0, 50, 5, 0, 1).split(" A ")[1].split(" ")[3], G.band(0, 0, 50, 5, 0, 0.5).split(" A ")[1].split(" ")[3]], ["1", "0"]);
eq("band: it starts and ends on the outer edge of the first level", [G.band(0, 0, 50, 4, 0, 0.5).startsWith("M " + Math.round(Math.cos(135 * Math.PI / 180) * 52 * 100) / 100)], [true]);

// The marks: every 10 %, those the level has reached on one path and the rest on the other, longer at 0, 50 and 100
const marks = (level, lit) => G.ticks(0, 0, 60, 3, level, lit).split("M ").filter(m => m).length;
eq("ticks: eleven marks, split between lit and not yet", [marks(0.35, true), marks(0.35, false), marks(0, true), marks(1, false)], [4, 7, 1, 0]);
eq("ticks: a mark lights as the level reaches it, not before", [marks(0.299, true), marks(0.3, true)], [3, 4]);
const lengthOf = (path, i) => { const [a, b] = path.split("M ").filter(m => m)[i].split(" L "); const [x0, y0] = a.trim().split(" ").map(Number), [x1, y1] = b.trim().split(" ").map(Number); return Math.round(Math.hypot(x1 - x0, y1 - y0) * 10) / 10; };
const all = G.ticks(0, 0, 60, 3, 1, true);
eq("ticks: longer at 0, 50 and 100 %", [lengthOf(all, 0), lengthOf(all, 1), lengthOf(all, 5), lengthOf(all, 10)], [5.1, 3, 5.1, 5.1]);

eq("conic: the seam sits in the middle of the gap, in Qt's counter-clockwise angle, and each colour holds over half the gap", [G.conic().angle, G.conic().edge], [270, 0.125]);

done();
