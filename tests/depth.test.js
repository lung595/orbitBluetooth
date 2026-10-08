// The sky's depth of field while a Listen together has the centre: when the blurred copy
// exists, when the live sky can stop, the blur radius, the veil, the atmosphere
// and how far what is not the group is pushed back (D294).
// Run from the plugin root: gjs tests/depth.test.js (or every file: sh tests/run.sh)
imports.searchPath.unshift(imports.system.programPath ? imports.system.programPath.replace(/\/[^\/]*$/, "") : "tests");
const { load, eq, done } = imports.lib;

const D = load("Depth.js", ["MIN_BLUR", "MAX_BLUR", "DIM", "ATMOSPHERE", "FAR_VEIL", "FAR_KEEP", "FAR_LABEL_KEEP", "FOCUS_DIM_KEEP", "clamp01", "level", "needsCopy", "covered", "blurRadius", "veilStrength", "atmosphereAlpha", "farVeilAlpha", "farOpacity", "farLabelOpacity", "focusDim"]);

// --- the depth shown -------------------------------------------------------------
eq("level: with motion it follows the camera, kept in 0..1", [D.level(0, true), D.level(0.3, true), D.level(1, true), D.level(-2, true), D.level(5, true)], [0, 0.3, 1, 0, 1]);
eq("level: with Reduce motion there is no dissolve, it flips half way", [D.level(0, false), D.level(0.49, false), D.level(0.5, false), D.level(1, false)], [0, 0, 1, 1]);

// --- the copy and the live sky -----------------------------------------------------
eq("copy: nothing exists outside a group (no depth, no cost)", [D.needsCopy(0), D.needsCopy(0.01), D.needsCopy(1)], [false, true, true]);
eq("covered: the live sky stops only at full depth, once the copy is rendered", [D.covered(1, true, 1), D.covered(1, false, 1), D.covered(0.99, true, 1), D.covered(0, true, 1)], [true, false, false, false]);
eq("covered: a gesture that brings the live part back (mix under 1) wakes it", [D.covered(1, true, 0), D.covered(1, true, 0.5)], [false, false]);

// --- the blur ------------------------------------------------------------------------
eq("blur: the same share of the short side on any scene", [D.blurRadius(520, 440), D.blurRadius(900, 300), D.blurRadius(440, 520)], [37, 25, 37]);
eq("blur: the bar popout's sky is really out of focus (counter-proof of the old 22 px, too sharp to be 'far')", D.blurRadius(520, 440) >= 30, true);
eq("blur: the black hole and its name are blurred past reading", D.blurRadius(100, 100) >= 12, true);
eq("blur: never under the minimum nor over what the effect can spread", [D.blurRadius(10, 10), D.blurRadius(0, 0), D.blurRadius(4000, 4000)], [D.MIN_BLUR, D.MIN_BLUR, D.MAX_BLUR]);

// --- the veil ---------------------------------------------------------------------------
eq("veil: unchanged outside a group, darker at full depth, never past full", [D.veilStrength(0.6, 0), D.veilStrength(0.6, 1) > 0.6, D.veilStrength(0.6, 1) <= 1, D.veilStrength(1, 1)], [0.6, true, true, 1]);
eq("veil: grows with the depth, step by step", [0, 0.25, 0.5, 0.75, 1].map(d => D.veilStrength(0.4, d)).every((v, i, all) => i === 0 || v > all[i - 1]), true);

// --- the atmosphere, the depth of what is not the group ------------------------------
eq("atmosphere: no glow outside a group, the full glow at full depth, never past it", [D.atmosphereAlpha(0), D.atmosphereAlpha(1), D.atmosphereAlpha(3), D.atmosphereAlpha(-1)], [0, D.ATMOSPHERE, D.ATMOSPHERE, 0]);
eq("atmosphere: a soft glow, not a fog (under a third of the opacity)", D.ATMOSPHERE > 0 && D.ATMOSPHERE <= 0.3, true);
eq("sky light: the blur conserves it, so little is taken away on top (a heavy dim averaged the stars to flat black)", D.DIM <= 0.25, true);
eq("far veil: none on Fedora's view, the full veil at full depth", [D.farVeilAlpha(0), D.farVeilAlpha(1), D.farVeilAlpha(9)], [0, D.FAR_VEIL, D.FAR_VEIL]);
eq("far: what is not the group keeps its opacity on Fedora's view and half of it at full depth", [D.farOpacity(0), D.farOpacity(1), D.farOpacity(2)], [1, D.FAR_KEEP, D.FAR_KEEP]);
eq("far: it fades step by step with the camera, and is restored on the way back", [1, 0.75, 0.5, 0.25, 0].map(d => D.farOpacity(d)).every((v, i, all) => i === 0 || v > all[i - 1]), true);
eq("far: the names are lighter still than the shapes, at every depth but none", [0.1, 0.5, 1].every(d => D.farLabelOpacity(d) < D.farOpacity(d)) && D.farLabelOpacity(0) === 1, true);
eq("focus dim: whole outside a group, softer under it, never gone", [D.focusDim(0.4, 0), D.focusDim(0.4, 1) < 0.4, D.focusDim(0.4, 1) > 0, D.focusDim(0.4, 1)], [0.4, true, true, 0.4 * D.FOCUS_DIM_KEEP]);

done();
