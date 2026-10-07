import QtQuick
import QtQuick.Window
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "../../components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Offscreen bench of "Orbit's tick only" (D360): a Listen together group at
// the centre, DMS's sound held back by DmsQuiet on a made-up settings object,
// and the group's level moved by the scene itself. Never grabs, never quits:
// it runs until the bench stops it. Made-up devices and outputs only.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports tick.qml -- <mode> /dev/null
// Modes: rest (the group landed, nothing moves), loop (the wheel on the
//        group's level, one step every 150 ms, up then down)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]

    width: 560
    height: 480
    visible: true
    color: "#101114"

    Component.onCompleted: {
        SettingsData.reduceMotion = true;
        Pipewire.playing = false;
        BluetoothService.available = true;
        BluetoothService.enabled = true;
        PluginService.globalVars = State.globals("together", Date.now());
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 20
        radius: 16
        color: "#07080c"
        clip: true

        OrbitScene {
            id: scene
            anchors.fill: parent
            active: true
            autoScan: false
            previewDevices: Devices.list(false, 2)
            audioRoute: fakeRoute
            cornerRadius: 16
        }
    }

    FakeRoute {
        id: fakeRoute
        sharing: ["02:00:00:00:10:06", "02:00:00:00:20:01", "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo"]
        // What the group's level called before writeLevels (the base of the
        // A/B bench runs this scene on its own components)
        function tickNodes(nodes, before, after) {
        }
    }

    // DMS's settings, made up: only the flags DmsQuiet holds
    QtObject {
        id: dmsSettings
        property bool osdVolumeEnabled: true
        property bool soundVolumeChanged: true
        property bool _selfWrite: false
    }

    // The overlay's DmsQuiet, or DmsOsdOff on a revision that predates it
    Loader {
        id: quiet
        Component.onCompleted: setSource("../../components/volume/DmsQuiet.qml", {
            "settings": dmsSettings,
            "osd": true,
            "replaceSound": true
        })
        onStatusChanged: {
            if (status === Loader.Error)
                setSource("../../components/volume/DmsOsdOff.qml", {
                    "settings": dmsSettings,
                    "active": true
                });
        }
    }

    readonly property var volume: scene.centre.volume
    readonly property bool landed: scene.centre.grouping === 1 && !scene.centre.travelling
    property int steps: 0

    // The wheel on the group's level, as VolumeOverlay wires it: the route
    // says a level is about to move, DmsQuiet holds DMS's sound back
    Timer {
        interval: 150
        repeat: true
        running: win.mode === "loop" && win.landed && win.volume.ready
        onTriggered: {
            if (quiet.item && quiet.item.hold)
                quiet.item.hold();
            win.volume.step(Math.floor(win.steps / 6) % 2 === 0 ? 1 : -1);
            win.steps++;
        }
    }
    // At rest DmsQuiet's own timers must be stopped (said once, for the log)
    Timer {
        interval: 5000
        running: true
        onTriggered: console.warn("tick bench:", win.mode, "landed", win.landed, "ready", win.volume.ready, "steps", win.steps, "level", win.volume.level.toFixed(2), "quiet", quiet.item ? (quiet.item.hold ? "DmsQuiet" : "DmsOsdOff") : "none", "wait", quiet.item && quiet.item.wait ? quiet.item.wait.running : "-", "sound", dmsSettings.soundVolumeChanged)
    }
}
