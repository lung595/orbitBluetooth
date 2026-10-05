// The volume radar's motion maths: easing, staggering, the level's glide and a dial's way from one slot to another.
// Run from the plugin root: gjs tests/radarMotion.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const M = load("RadarMotion.js", ["ENTRANCE", "STAGGER", "MORPH", "RIPPLE", "GLIDE", "SNAP", "clamp", "ease", "mix", "phase", "follow", "slotMix"]);

const near = v => Math.round(v * 1000) / 1000;

// --- easing -----------------------------------------------------------------------
eq("ease: it starts at 0 and ends at 1, held there beyond", [M.ease(0), M.ease(1), M.ease(-2), M.ease(3)], [0, 1, 0, 1]);
eq("ease: quick at first, soft at the end (more than half done at the half)", [M.ease(0.5) > 0.5, M.ease(0.9) - M.ease(0.8) < M.ease(0.1) - M.ease(0)], [true, true]);
eq("ease: it never goes back", [0.1, 0.3, 0.5, 0.7, 0.9].every((t, i, all) => i === 0 || M.ease(t) > M.ease(all[i - 1])), true);
eq("mix: both ends and the middle", [M.mix(10, 20, 0), M.mix(10, 20, 1), M.mix(10, 20, 0.5)], [10, 20, 15]);

// --- a stretch of the timeline ----------------------------------------------------
eq("phase: nothing before the stretch, all of it after", [M.phase(0.05, 0.1, 0.2), M.phase(0.3, 0.1, 0.2), M.phase(5, 0.1, 0.2)], [0, 1, 1]);
eq("phase: inside the stretch it is the eased part", near(M.phase(0.2, 0.1, 0.2)), near(M.ease(0.5)));
eq("phase: a stretch with no length is a step", [M.phase(0.9, 1, 0), M.phase(1, 1, 0)], [0, 1]);
eq("stagger: the small dials come in one after the other, the last one still within the entrance", [0, 1, 2, 3].map(i => M.phase(0.12 + M.STAGGER * i + 0.001, 0.12 + M.STAGGER * i, 0.25) < M.phase(0.12 + M.STAGGER * i + 0.1, 0.12 + M.STAGGER * i, 0.25)), [true, true, true, true]);
eq("stagger: a later dial is behind an earlier one at the same moment", M.phase(0.3, 0.12 + M.STAGGER * 3, 0.25) < M.phase(0.3, 0.12, 0.25), true);
eq("entrance: it is long enough for the last of five dials, and a short moment", [0.12 + M.STAGGER * 4 + 0.25 <= M.ENTRANCE + M.STAGGER * 4 + 0.01, M.ENTRANCE < 1], [true, true]);

// --- a level's glide --------------------------------------------------------------
const step = (from, to, seconds, rate) => {
    let v = from;
    for (let i = 0; i < Math.round(seconds * 60); i++)
        v = M.follow(v, to, 1 / 60, rate);
    return v;
};
eq("follow: it moves toward the target, not past it", [M.follow(0, 1, 1 / 60, M.GLIDE) > 0, M.follow(0, 1, 1 / 60, M.GLIDE) < 1, M.follow(1, 0, 1 / 60, M.GLIDE) < 1], [true, true, true]);
eq("follow: it lands on the target and stays there (no creeping for ever)", [step(0, 0.8, 1, M.GLIDE), step(0.8, 0.8, 1, M.GLIDE)], [0.8, 0.8]);
eq("follow: a target within the snap is taken at once", M.follow(0.5, 0.5 + M.SNAP / 2, 1 / 60, M.GLIDE), 0.5 + M.SNAP / 2);
eq("follow: the same at any frame rate", near(step(0, 1, 0.2, M.GLIDE)) === near((() => { let v = 0; for (let i = 0; i < 24; i++) v = M.follow(v, 1, 0.2 / 24, M.GLIDE); return v; })()), true);
eq("follow: it is about done in a fifth of a second for a quick glide, so a drag feels fluid", [step(0, 1, 0.2, M.GLIDE) > 0.9, step(0, 1, 0.02, M.GLIDE) < 0.5], [true, true]);

// --- a dial's way from a slot to another ------------------------------------------
const a = { x: 0, y: 0, r: 90 }, b = { x: 100, y: -140, r: 30 };
eq("slotMix: both ends, and the middle", [M.slotMix(a, b, 0), M.slotMix(a, b, 1), M.slotMix(a, b, 0.5)], [a, b, { x: 50, y: -70, r: 60 }]);
eq("slotMix: eased by the morph, a swap ends exactly on the slot", [M.slotMix(a, b, M.phase(M.MORPH, 0, M.MORPH)), M.slotMix(a, b, M.phase(M.MORPH * 2, 0, M.MORPH))], [b, b]);
eq("slotMix: the old hero and the tapped dial cross smoothly (the radius shrinks and grows together)", [M.slotMix(a, b, 0.5).r < a.r, M.slotMix(b, a, 0.5).r > b.r], [true, true]);

// --- the moments ------------------------------------------------------------------
eq("moments: all short, so the clock stops quickly", [M.ENTRANCE, M.MORPH, M.RIPPLE].every(s => s > 0 && s <= 0.6), true);
eq("glide: a rate of a few per second at least", M.GLIDE >= 8, true);

done();
