.pragma library

// Which charging beam is drawn. The setting `chargeBeamStyle` and the IPC
// command `beamStyle` both go through parse(), so a value that is not in the
// list (a typo, a style from a newer version) is the default, never a blank
// beam. Pure; tested by tests/beamStyle.test.js.

var STYLES = ["pulse", "filament", "chain", "horizon"];
var DEFAULT = "filament";

// The style a stored or typed value names, or the default
function parse(value) {
    const s = String(value ?? "").trim().toLowerCase();
    return STYLES.indexOf(s) < 0 ? DEFAULT : s;
}
