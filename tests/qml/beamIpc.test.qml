import QtQuick
import qs.Services
import "components/scene"

// Test of the path from the `beamStyle` IPC command and the saved setting to
// the style the scene draws (OrbitDaemonData.beamStyle): the global the IPC
// sets wins over the setting, an empty one (reset) gives the setting back, and
// a value that names no style is Filament. Run with tests/qml/run.sh.
Item {
    id: h

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // Stand-in for the scene: only what the daemon data reads
    QtObject {
        id: fakeScene
        property bool awake: false
        property bool btOn: false
        property var prefs: ({
                "pluginId": "orbitTest",
                "chargeBeamStyle": "pulse"
            })
    }

    OrbitDaemonData {
        id: daemon
        scene: fakeScene
    }

    // The IPC handler stores its answer in the plugin's global variables
    function ipc(value) {
        PluginService.globalVars = {
            "orbitTest": {
                "beamStyle": value
            }
        };
    }

    Component.onCompleted: {
        check("no IPC value: the saved setting", daemon.beamStyle, "pulse");
        ipc("filament");
        check("the IPC value wins over the setting", daemon.beamStyle, "filament");
        ipc("");
        check("reset (empty): the setting is back", daemon.beamStyle, "pulse");
        ipc("nonsense");
        check("an IPC value that names no style is Filament", daemon.beamStyle, "filament");
        PluginService.globalVars = {};
        fakeScene.prefs = {
            "pluginId": "orbitTest",
            "chargeBeamStyle": "nonsense"
        };
        check("a saved setting that names no style is Filament", daemon.beamStyle, "filament");
        fakeScene.prefs = {
            "pluginId": "orbitTest"
        };
        check("no setting at all is Filament", daemon.beamStyle, "filament");
        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
