// Outputs listening together on the face (D254, D277): what is heard, how big each
// part of the picture is, how the levels glide, and the colour of each output.
// Run from the plugin root: gjs tests/members.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const Palette = load("Palette.js", ["fromHsl", "toHsl", "isGrey", "apart"]);
const Polar = load("Polar.js", ["heardLevel", "scaleFor"]);
const Members = load("Members.js", ["heardOf", "scales", "scaleAt", "easeAll", "settled", "sectors"]);
const MemberColors = load("MemberColors.js", ["pick"]);

const m = (level, muted) => ({ "level": level, "muted": !!muted });
const round2 = v => Math.round(v * 100) / 100;

// --- What is heard, and how big the picture is ------------------------------------
eq("heard with no output: this PC's level alone", [Members.heardOf([], 0.8, false), Members.heardOf([], 0.8, true)], [0.8, 0]);
eq("heard: the loudest output's, times this PC's", round2(Members.heardOf([m(0.5), m(0.9)], 0.8, false)), 0.72);
eq("heard: a muted output is silent, the others still count", round2(Members.heardOf([m(0.9, true), m(0.5)], 0.8, false)), 0.4);
eq("heard: every output muted, or this PC muted, is silence", [Members.heardOf([m(0.9, true), m(0.5, true)], 0.8, false), Members.heardOf([m(0.9), m(0.5)], 0.8, true)], [0, 0]);
eq("each part of the picture next to the loudest one's", Members.scales([0.72, 0.36]).map(round2), [1, round2(Polar.scaleFor(0.36) / Polar.scaleFor(0.72))]);
eq("silence everywhere: every part the same size", [Members.scales([0, 0, 0]), Members.scales([])], [[1, 1, 1], []]);
eq("size along the half circle blends from one part's middle to the next's", [0, 0.25, 0.5, 0.75, 1].map(p => Members.scaleAt([1, 0.5], p)), [1, 1, 0.75, 0.5, 0.5]);
eq("size with one part, or none", [Members.scaleAt([0.7], 0.3), Members.scaleAt([], 0.3)], [0.7, 1]);
eq("size with four parts: exact in the middle of each", [0.125, 0.375, 0.625, 0.875].map(p => Members.scaleAt([1, 0.8, 0.6, 0.4], p)).map(round2), [1, 0.8, 0.6, 0.4]);

// --- The levels glide on one clock ------------------------------------------------
eq("a level that just joined starts at its target", Members.easeAll([0.2], [0.2, 0.6], 0, 10), [0.2, 0.6]);
eq("the others glide toward theirs", Members.easeAll([0, 1], [1, 0], 100, 10).map(round2), [1, 0]);
eq("a level that left is dropped", Members.easeAll([0.5, 0.5, 0.5], [0.5, 0.5], 0.01, 10).length, 2);
eq("settled: same count, within tolerance", [Members.settled([1, 0.5], [1, 0.505], 0.01), Members.settled([1, 0.5], [1, 0.6], 0.01), Members.settled([1], [1, 0.5], 0.01), Members.settled([], [], 0.01)], [true, false, false, true]);

// --- The colour of each output ----------------------------------------------------
const hsl = (h, s, l) => Palette.fromHsl(h, s, l);
const hueGap = (a, b) => { const d = Math.abs(Palette.toHsl(a).h - Palette.toHsl(b).h); return Math.min(d, 1 - d); };
const gaps = list => list.flatMap((a, i) => list.slice(i + 1).map(b => hueGap(a, b)));
const rgb = c => [c.r, c.g, c.b].map(round2);
const apartBases = [hsl(0, 0.7, 0.6), hsl(0.45, 0.7, 0.6), hsl(0.72, 0.7, 0.6)];
const alike = [hsl(0.75, 0.6, 0.8), hsl(0.76, 0.2, 0.75), hsl(0.78, 0.5, 0.82)];
const greys = [hsl(0, 0, 0.8), hsl(0, 0.05, 0.7), hsl(0, 0, 0.6)];

// The cloud's sectors
const outs = [{ color: "red", muted: false }, { color: "green", muted: true }];
eq("sectors: one per output, the loudest at full size", Members.sectors(outs, [0.5, 0.25], "blue", false).map(s => [s.color, s.quiet, s.scale === 1]), [["red", false, true], ["green", true, false]]);
eq("sectors: a muted PC quiets them all", Members.sectors(outs, [0.5, 0.5], "blue", true).map(s => s.quiet), [true, true]);
eq("sectors: no output, this PC's alone", Members.sectors([], [], "blue", false), [{ color: "blue", scale: 1, quiet: false }]);
eq("accents that already differ are kept as they are", MemberColors.pick(apartBases, 2).map(rgb), [apartBases[0], apartBases[1], apartBases[2]].map(rgb));
// Hues 0.2 / 0.7 / 0.47: the tertiary is 0.23 of a turn from the secondary, close but plainly another colour
const near = [hsl(0.2, 0.7, 0.6), hsl(0.7, 0.7, 0.6), hsl(0.47, 0.7, 0.6)];
eq("accents a little under an even spread apart are still kept (D254)", MemberColors.pick(near, 2).map(rgb), near.map(rgb));
eq("a single output keeps the colours it always had (D270)", MemberColors.pick(alike, 1).map(rgb), [alike[0], Palette.apart(alike[2], alike[0])].map(rgb));
eq("an output and this PC: count + 1 colours", [1, 2, 3, 4].map(n => MemberColors.pick(apartBases, n).length), [2, 3, 4, 5]);
eq("a count out of range is clamped", [MemberColors.pick(apartBases, 0).length, MemberColors.pick(apartBases, 9).length], [2, 5]);
eq("the first output always keeps the primary", [alike, greys].map(b => rgb(MemberColors.pick(b, 3)[0])), [alike, greys].map(b => rgb(b[0])));
// A grey primary stays (a monochrome theme), so the first colour is left out of the checks
for (const [name, bases] of [["similar accents", alike], ["grey accents", greys], ["distinct accents", apartBases]]) {
    for (const n of [2, 3, 4]) {
        const colors = MemberColors.pick(bases, n).slice(bases === greys ? 1 : 0);
        eq(name + ", " + n + " outputs: no two pass for each other", Math.min(...gaps(colors)) >= (n === 2 ? 0.2 : 0.1), true);
        eq(name + ", " + n + " outputs: none is grey", colors.some(Palette.isGrey), false);
    }
}
const turned = MemberColors.pick(alike, 2)[1];
eq("a turned colour keeps its accent's lightness", round2(Palette.toHsl(turned).l), round2(Palette.toHsl(alike[1]).l));
done();
