// The radar's sky: which stars fall where, the orbit's dashes and how bright each is, what is kept clear.
// Run from the plugin root: gjs tests/radarSky.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const S = load("RadarSky.js", ["SEED", "FLOOR", "FADE", "top", "starCount", "clearings", "isClear", "stars", "orbitAlpha", "dashes"]);
const G = load("RadarRandom.js");
const R = load("Radar.js", ["layout", "ORBIT", "ACTIONS"]);

const near = v => Math.round(v * 1000) / 1000;
const side = 300, w = 360, header = 120, cx = w / 2, cy = 260;
const places = n => R.layout("hero", n, side);
const actionsY = cy + places(3).hero.r + 14;
const clear = n => S.clearings(places(n), cx, cy, w, actionsY);
const top = S.top(header);

// --- the generator and the count ---------------------------------------------------
const draw = () => { const r = G.random(S.SEED); return [r(), r(), r()]; };
eq("random: the same seed gives the same sky every time, in 0..1", [JSON.stringify(draw()) === JSON.stringify(draw()), draw().every(v => v >= 0 && v < 1)], [true, true]);
eq("random: another seed gives another sequence", G.random(1)() !== G.random(2)(), true);
eq("top: the sky starts 8 px under the header", S.top(120), 128);
eq("count: one star per 2 500 px², at most 60, none for no room", [S.starCount(360, 250), S.starCount(360, 900), S.starCount(120, 0)], [36, 60, 0]);

// --- what is kept clear -----------------------------------------------------------------
const c4 = clear(4);
eq("clearings: a disc for the hero and one for each small dial, a name strip each and the actions' band", [c4.discs.length, c4.rects.length], [5, 5]);
eq("clearings: the hero's disc is its ring and 8 px, on the hero's offset place", [c4.discs[0].r, c4.discs[0].x, c4.discs[0].y], [places(4).hero.r + 8, cx + places(4).hero.x, cy + places(4).hero.y]);
const s0 = places(4).satellites[0];
eq("clearings: a small dial's disc is its radius and 6 px, its name strip is 14 px high under it, at least 72 wide", [c4.discs[1].r, c4.rects[0].h - 8, c4.rects[0].w - 8, c4.rects[0].y + 4 - (cy + s0.y + s0.r)], [s0.r + 6, 14, Math.max(72, 3 * s0.r), 2]);
eq("clearings: the actions' band is the room the card reserves, the card's width across", [c4.rects[4].h - 8, c4.rects[4].y + 4], [R.ACTIONS, actionsY]);
eq("clearings: they follow the offset places, the orbit's ideal ring is not where the dials are", [c4.discs[0].x === cx + places(4).hero.x && c4.discs[0].y === cy + places(4).hero.y && c4.discs.slice(1).every((d, k) => d.x === cx + places(4).satellites[k].x && d.y === cy + places(4).satellites[k].y), places(4).satellites.some(s => Math.abs(Math.hypot(s.x, s.y) - R.ORBIT * side) > 1)], [true, true]);
eq("clearings: a lone hero keeps only itself and the band", [clear(0).discs.length, clear(0).rects.length], [1, 1]);
eq("isClear: the hero's middle, a small dial's name and the actions are not, the corner is", [S.isClear(c4, cx, cy, 0), S.isClear(c4, cx + s0.x, cy + s0.y + s0.r + 8, 0), S.isClear(c4, cx, actionsY + 10, 0), S.isClear(c4, 2, top + 2, 0)], [false, false, false, true]);
eq("isClear: the margin counts", [S.isClear(c4, cx + c4.discs[0].r + 1, cy, 0), S.isClear(c4, cx + c4.discs[0].r + 1, cy, 2)], [true, false]);

// --- the stars --------------------------------------------------------------------------------
const body = 380 - top;
const sky = S.stars(w, top, body, c4);
eq("stars: never more than wanted, and some", [sky.length <= S.starCount(w, body), sky.length > 10], [true, true]);
eq("stars: all in the sky, under the header", sky.every(s => s.x >= 0 && s.x <= w && s.y >= top && s.y <= top + body), true);
eq("stars: none in a clearing", sky.every(s => S.isClear(c4, s.x, s.y, s.r)), true);
eq("stars: faint small ones and a few big ones, only the big ones tinted", [sky.every(s => s.a >= 0.1 && s.a <= 0.3), sky.some(s => s.r > 0.9), sky.filter(s => s.tinted).every(s => s.r >= 0.9)], [true, true, true]);
eq("stars: the same sky each time, and the dials change it only where they stand", [JSON.stringify(S.stars(w, top, body, c4)) === JSON.stringify(sky), sky.length === S.stars(w, top, body, clear(0)).length || S.stars(w, top, body, clear(0)).length >= sky.length], [true, true]);
eq("stars: a tiny card has few, an empty one none", [S.stars(120, 40, 20, clear(0)).length <= 1, S.stars(300, 40, 0, clear(0)).length], [true, 0]);

// --- the orbit ----------------------------------------------------------------------------------
eq("alpha: full along the satellites' arc, FLOOR beyond it", [S.orbitAlpha(0, false), S.orbitAlpha(70, false), S.orbitAlpha(120, false), S.orbitAlpha(180, true)], [0.22, 0.22, S.FLOOR, S.FLOOR]);
eq("alpha: the light theme is a little stronger", [S.orbitAlpha(0, true), S.orbitAlpha(0, true) > S.orbitAlpha(0, false)], [0.26, true]);
eq("alpha: it fades over 12° and never under FLOOR", [S.orbitAlpha(72, false) < 0.22, S.orbitAlpha(72, false) > S.FLOOR, S.orbitAlpha(82, false), S.orbitAlpha(81.9, true) >= S.FLOOR], [true, true, S.FLOOR, true]);
const R_ORBIT = R.ORBIT * side;
const ring = S.dashes(R_ORBIT, cx, cy, false, clear(0));
const spans = g => g.flatMap(x => x.spans);
const circumference = 2 * Math.PI * R_ORBIT;
eq("dashes: a dash every 8 px round the whole ring, 2 px long, but where the hero's actions are", [spans(ring).length <= Math.ceil(circumference / 8), spans(ring).length > circumference / 8 - 40, spans(ring).every(([a, b]) => near((b - a) * R_ORBIT) === 2)], [true, true, true]);
eq("dashes: full at the top, FLOOR at the bottom", [near(ring.find(g => g.spans.some(([a]) => Math.abs(a + Math.PI / 2) < 0.05)).a), ring.map(g => g.a).includes(0.22), ring.every(g => g.a >= S.FLOOR && g.a <= 0.22)], [0.22, true, true]);
eq("dashes: grouped by alpha, one group per alpha", ring.length === new Set(ring.map(g => g.a)).size, true);
const mid = ([a, b]) => ({ "x": cx + Math.cos((a + b) / 2) * R_ORBIT, "y": cy + Math.sin((a + b) / 2) * R_ORBIT });
eq("dashes: none passes through a clearing", spans(S.dashes(R_ORBIT, cx, cy, false, c4)).every(s => S.isClear(c4, mid(s).x, mid(s).y, 0)), true);
eq("dashes: more dials, fewer dashes (the ring passes behind them)", spans(S.dashes(R_ORBIT, cx, cy, false, clear(5))).length < spans(ring).length, true);

done();
