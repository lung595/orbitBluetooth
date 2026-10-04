// The sky's depth of field while a Listen together has the centre: when the blurred copy
// exists, when the live sky can stop, the blur radius and the veil (D294).
// Run from the plugin root: gjs tests/depth.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const D = load("Depth.js", ["MIN_BLUR", "MAX_BLUR", "clamp01", "level", "needsCopy", "covered", "blurRadius", "veilStrength"]);

// --- the depth shown -------------------------------------------------------------
eq("level: with motion it follows the camera, kept in 0..1", [D.level(0, true), D.level(0.3, true), D.level(1, true), D.level(-2, true), D.level(5, true)], [0, 0.3, 1, 0, 1]);
eq("level: with Reduce motion there is no dissolve, it flips half way", [D.level(0, false), D.level(0.49, false), D.level(0.5, false), D.level(1, false)], [0, 0, 1, 1]);

// --- the copy and the live sky -----------------------------------------------------
eq("copy: nothing exists outside a group (no depth, no cost)", [D.needsCopy(0), D.needsCopy(0.01), D.needsCopy(1)], [false, true, true]);
eq("covered: the live sky stops only at full depth, once the copy is rendered", [D.covered(1, true, 1), D.covered(1, false, 1), D.covered(0.99, true, 1), D.covered(0, true, 1)], [true, false, false, false]);
eq("covered: a gesture that brings the live part back (mix under 1) wakes it", [D.covered(1, true, 0), D.covered(1, true, 0.5)], [false, false]);

// --- the blur ------------------------------------------------------------------------
eq("blur: the same share of the short side on any scene", [D.blurRadius(520, 440), D.blurRadius(900, 300), D.blurRadius(440, 520)], [22, 15, 22]);
eq("blur: never under the minimum nor over what the effect can spread", [D.blurRadius(10, 10), D.blurRadius(0, 0), D.blurRadius(4000, 4000)], [D.MIN_BLUR, D.MIN_BLUR, D.MAX_BLUR]);

// --- the veil ---------------------------------------------------------------------------
eq("veil: unchanged outside a group, darker at full depth, never past full", [D.veilStrength(0.6, 0), D.veilStrength(0.6, 1) > 0.6, D.veilStrength(0.6, 1) <= 1, D.veilStrength(1, 1)], [0.6, true, true, 1]);
eq("veil: grows with the depth, step by step", [0, 0.25, 0.5, 0.75, 1].map(d => D.veilStrength(0.4, d)).every((v, i, all) => i === 0 || v > all[i - 1]), true);

done();
