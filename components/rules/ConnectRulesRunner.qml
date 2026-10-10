import QtQuick
import "ConnectRules.js" as Rules

// Runs the connection rules (ConnectRules.js) when a device connects. It only
// sequences: the pure module decides, the owner applies each action through the
// signals, in the order given (volume first). Event-driven, no timer, nothing
// written outside Orbit's own settings. Not loaded by any view yet.
QtObject {
    id: runner

    // Orbit's stored rules, { <key>: { volume, noise } }, and the random salt
    // that keeps the keys from being turned back into addresses.
    property var rules: ({})
    property string salt: ""

    signal volumeRequested(string address, int value)
    signal noiseRequested(string address, string mode)
    // A rule action that could not run, with a reason code of ConnectRules.js.
    signal skipped(string address, string kind, string reason)

    property var _state: Rules.newState()

    // `device`: { volume: bool, noiseModes: [names] }
    function deviceConnected(address, device) {
        const key = Rules.keyOf(address, salt);
        const plan = Rules.onConnected(_state, key, (rules || {})[key], device, Date.now());
        _state = plan.state;
        for (const a of plan.actions) {
            if (a.kind === "volume")
                volumeRequested(address, a.value);
            else
                noiseRequested(address, a.mode);
        }
        for (const s of plan.skipped)
            skipped(address, s.kind, s.reason);
    }

    // Call when the user moves a device's volume, so a lowered level is kept.
    function userVolume(address, level) {
        _state = Rules.noteUserVolume(_state, Rules.keyOf(address, salt), level);
    }
}
