import QtQuick
import QtQuick.Window
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../../components/volume"

// Offscreen bench of AudioRoute's volume keys outside a group (NAK-196): two
// made-up headsets with their own level and this PC's virtual sink, whose
// levels move on a plain assignment as PipeWire reports them back. Nothing is
// drawn but an empty window; what this measures is the route's logic (the
// keys' target, the echo book, one level watcher per device and one for this
// PC). Never grabs, never quits. Made-up addresses only.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports -I ../../tests/qml/stubs alone.qml -- <mode> /dev/null
// Modes: rest (two headsets connected, nothing moves), keys (the target is the
//        headset that does not play, one key step every 40 ms as a held key
//        repeats), keyspc (the same with this PC's level as the target),
//        foreign (the headset that does not play moves by itself every 40 ms,
//        as its own buttons held down would)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]

    width: 120
    height: 80
    visible: true
    color: "#101114"

    component Sink: QtObject {
        required property string name
        readonly property bool isSink: true
        readonly property bool isStream: false
        readonly property bool ready: true
        readonly property QtObject audio: QtObject {
            property real volume: 0.5
            property bool muted: false
        }
    }
    // The fields of a BlueZ device AudioRoute reads
    component Device: QtObject {
        property string address
        property string name
        property bool connected: false
    }
    Sink {
        id: s1
        name: "bluez_output.02_00_00_00_00_01.1"
    }
    Sink {
        id: s2
        name: "bluez_output.02_00_00_00_00_02.1"
    }
    Sink {
        id: p1
        name: "orbit_pc_02_00_00_00_00_01"
    }
    Device {
        id: d1
        address: "02:00:00:00:00:01"
        name: "Fictional One"
        connected: true
    }
    Device {
        id: d2
        address: "02:00:00:00:00:02"
        name: "Fictional Two"
        connected: true
    }

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

    Component.onCompleted: {
        Pipewire.extraSinks = [s1, s2, p1];
        Pipewire.defaultAudioSink = s1;
        Bluetooth.devices = [d1, d2];
        route.known(d1.address).absolute = 1;
        route.known(d2.address).absolute = 1;
        // On the base the target outside a group is always the output you
        // hear: the same key then steps it, which is what the A/B compares
        if (mode === "keys")
            route.touch(d2.address);
        else if (mode === "keyspc")
            route.touch("pc");
    }

    // Up then down, so a long run never pins the level at an end
    property int _n: 0
    Timer {
        interval: 40
        repeat: true
        running: win.mode !== "rest"
        onTriggered: {
            const up = Math.floor(win._n++ / 20) % 2 === 0;
            if (win.mode === "foreign")
                s2.audio.volume = Math.max(0, Math.min(1, s2.audio.volume + (up ? 0.02 : -0.02)));
            else
                route.stepHeard(up ? 1 : -1);
        }
    }
}
