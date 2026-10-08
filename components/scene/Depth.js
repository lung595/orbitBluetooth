.pragma library

// The sky's depth of field while a Listen together has the centre (D294): the
// farther from the camera, the blurrier and the more veiled, so the stars, the
// veil, the black hole and the host's system fall behind the group, as if the
// group stood on a planet and all the rest were far. Pure functions of the
// depth (0 = sharp, 1 = full); the QML only reads them. Tested by
// tests/depth.test.js.

var DIM = 0.2;          // share of the sky's light taken away at full depth (blend toward black, 0..1): a blur conserves light, a heavy dim on top would average the stars to a flat black
var LIFT = 0.04;        // brightness given back to the blurred copy (an offset: the sky never reads as pure black behind the group)
var VIVID = 0.5;        // saturation given to it: a blur greys the colours of the faint nebulae
var ATMOSPHERE = 0.16;  // alpha of the soft glow of the sky's own colour behind the group, at full depth
var VEIL = 0.75;        // share of the desktop veil's missing strength it gains at full depth
var FAR_VEIL = 0.5;     // alpha of the veil laid between the host's system and the group, at full depth
var FAR_KEEP = 0.5;     // share of its opacity what is not the group keeps at full depth (the host's orbits and waves)
var FAR_LABEL_KEEP = 0.3;   // the same for the names, lighter still: small text is what stays readable the longest
var FOCUS_DIM_KEEP = 0.25;  // share of the focus dim a solid sky keeps at full depth: the blur already darkens it
var MIN_BLUR = 12;      // px, the blur radius on the smallest part (the black hole and its name)
var MAX_BLUR = 64;      // px, the most MultiEffect's blur can spread
var BLUR_SHARE = 12;    // the radius is the scene's short side over this: the same look on any size
var HALF = 0.5;         // with Reduce motion the sky is either sharp or blurred, at half way

function clamp01(v) {
    return Math.max(0, Math.min(1, v));
}

// The depth the sky shows. With motion it follows the camera's progress; with
// Reduce motion there is no dissolve: it flips once the camera is half way.
function level(depth, motion) {
    const d = clamp01(depth);
    return motion ? d : (d >= HALF ? 1 : 0);
}

// Whether the blurred copy has to exist (any depth, even a brief one)
function needsCopy(shown) {
    return shown > 0;
}

// Whether the live sky can stop: the blurred copy is rendered (`ready`) and
// fully opaque (`shown`, and `mix` = 1 unless a gesture is bringing the live
// part back), so nothing of the live sky is seen: it need not be drawn,
// animated or measured (the copy is a plain texture)
function covered(shown, ready, mix) {
    return shown >= 1 && ready && mix >= 1;
}

// Blur radius (px) for a scene: the same share of its short side everywhere
function blurRadius(width, height) {
    const r = Math.round(Math.min(width, height) / BLUR_SHARE);
    return Math.max(MIN_BLUR, Math.min(MAX_BLUR, r));
}

// The desktop veil is a dark smoky layer over the wallpaper: it gets darker
// with the depth (blurring a smooth gradient would show nothing)
function veilStrength(base, shown) {
    const b = clamp01(base);
    return b + (1 - b) * VEIL * clamp01(shown);
}

// The soft glow of the sky's own colour behind the group (alpha): the deep
// atmosphere the blurred stars float in, so the sky does not average to black
function atmosphereAlpha(shown) {
    return ATMOSPHERE * clamp01(shown);
}

// The veil laid between the host's system and the group (alpha, desktop glass
// and solid sky alike): the wallpaper cannot be blurred, so what is far is
// pushed back behind a frosted layer instead
function farVeilAlpha(shown) {
    return FAR_VEIL * clamp01(shown);
}

// The opacity of what is not the group (the host's orbits and waves): it keeps
// FAR_KEEP of it at full depth
function farOpacity(shown) {
    return 1 - (1 - FAR_KEEP) * clamp01(shown);
}

// The same for names (the host's, the hole's): lighter still
function farLabelOpacity(shown) {
    return 1 - (1 - FAR_LABEL_KEEP) * clamp01(shown);
}

// The dimming laid over a solid sky while a card is open: softer under a
// group, as the sky behind it is already blurred and dark
function focusDim(base, shown) {
    return base * (1 - (1 - FOCUS_DIM_KEEP) * clamp01(shown));
}
