import QtQuick
import QtQuick.Window
import Quickshell.Services.Pipewire
import "../../components/volume"

// Offscreen bench of AudioRoute's own share of the volume keys (NAK-174): the
// daemon's route with made-up wired outputs whose levels move on a plain
// assignment, as PipeWire reports them back. Nothing is drawn but an empty
// window; what this measures is the route's logic (the keys' target, the
// echo book, one level watcher per member). Never grabs, never quits.
// Made-up sink names only.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports -I ../../tests/qml/stubs route.qml -- <mode> /dev/null
// Modes: rest (three outputs listening together, nothing moves), keys (the
//        same group, one member the keys' target, one key step every 40 ms
//        as a held key repeats, up then down), drag (no group, one output's
//        level written at 60 Hz as the scope's drag does, up then down)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]
    readonly property bool grouped: mode !== "drag"

    width: 120
    height: 80
    visible: true
    color: "#101114"

    QtObject {
        id: prefs
        property bool volumeTick: false
        property bool tickAlone: true
        property bool separatePc: true
        property var pcLevels: ({})
        property string volumeSteps: "fixed"
        property int volumeStep: 2
        property string volumeSpeed: "balanced"
        property int togetherFineDelay: 0
    }
    AudioRoute {
        id: route
        prefs: prefs
    }

    Component {
        id: fakeOutput
        QtObject {
            required property string name
            readonly property bool isSink: true
            readonly property bool isStream: false
            readonly property bool ready: true
            readonly property QtObject audio: QtObject {
                property real volume: 0.5
                property bool muted: false
            }
        }
    }
    property var outputs: []
    Component.onCompleted: {
        outputs = [1, 2, 3].map(i => fakeOutput.createObject(win, {
                "name": "alsa_output.fictional-dac-" + i + ".analog-stereo"
            }));
        Pipewire.extraSinks = outputs;
        if (grouped) {
            route.together.members = outputs.map(o => o.name);
            route.touch(outputs[1].name);
        }
    }

    // Up then down, so a long run never pins the level at an end
    property int _n: 0
    Timer {
        interval: win.mode === "keys" ? 40 : 16
        repeat: true
        running: win.mode === "keys" || win.mode === "drag"
        onTriggered: {
            const up = Math.floor(win._n++ / 20) % 2 === 0;
            if (win.mode === "keys") {
                route.stepHeard(up ? 1 : -1);
            } else {
                const node = win.outputs[0];
                route.writeLevel(node, Math.max(0, Math.min(1, node.audio.volume + (up ? 0.01 : -0.01))));
            }
        }
    }
}
