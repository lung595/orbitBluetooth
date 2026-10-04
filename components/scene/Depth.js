.pragma library

// The sky's depth of field while a Listen together has the centre (D294): the
// farther from the camera, the darker and the blurrier, so the stars, the veil
// and the black hole fall behind the group. Pure functions of the depth
// (0 = sharp, 1 = full); the QML only reads them. Tested by tests/depth.test.js.

var DIM = 0.5;          // share of the sky's light taken away at full depth (blend toward black, 0..1)
var VEIL = 0.5;         // share of the desktop veil's missing strength it gains at full depth
var MIN_BLUR = 8;       // px, the blur radius on the smallest scene
var MAX_BLUR = 64;      // px, the most MultiEffect's blur can spread
var BLUR_SHARE = 20;    // the radius is the scene's short side over this: the same look on any size
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
