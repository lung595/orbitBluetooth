.pragma library

// Which charging beam is drawn. The setting `chargeBeamStyle` and the IPC
// command `beamStyle` both go through parse(), so a value that is not in the
// list (a typo, a style from a newer version) is the default, never a blank
// beam. Pure; tested by tests/beamStyle.test.js.

var STYLES = ["pulse", "filament", "chain", "horizon"];
var DEFAULT = "filament";
// What can be drawn today. Chain and Horizon are listed (the setting offers
// them) but fall back to Filament until their components land.
var DRAWN = ["pulse", "filament"];

// The style a stored or typed value names, or the default
function parse(value) {
    const s = String(value ?? "").trim().toLowerCase();
    return STYLES.indexOf(s) < 0 ? DEFAULT : s;
}

// The style actually drawn for a value: itself, or the default when its
// component does not exist yet
function drawn(value) {
    const s = parse(value);
    return DRAWN.indexOf(s) < 0 ? DEFAULT : s;
}
