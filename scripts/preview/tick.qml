import QtQuick
import QtQuick.Window
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "../../components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State
import "../../components/centre/Gauge.js" as Gauge

// Offscreen bench of "Orbit's tick only" (D360): a Listen together group at
// the centre, DMS's sound held back by DmsQuiet on a made-up settings object,
// and the group's level moved by the scene itself. Never grabs, never quits:
// it runs until the bench stops it. Made-up devices and outputs only.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports tick.qml -- <mode> /dev/null
// Modes: rest (the group landed, nothing moves), loop (the wheel on the
//        group's level, one step every 150 ms, up then down), drag (the
//        pointer held on the gauge and swept along its arc at 60 Hz, up then
//        down, through the ring's own press/drag), hidden (the group landed,
//        then the view frozen as when it is covered)
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
            // hidden: frozen once the group has landed, as a covered view
            active: !(win.mode === "hidden" && win.landed)
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

    // The ring that carries the gauge, found by what it does (its press and
    // drag), so the scene runs on revisions that name it or not
    function findRing(item) {
        if (typeof item.drag === "function" && typeof item.press === "function" && item.held !== undefined)
            return item;
        for (const c of item.children) {
            const r = findRing(c);
            if (r)
                return r;
        }
        return null;
    }
    property var ring: null
    property real sweep: 0
    // A held pointer swept along the arc at 60 Hz, 0 to 1 and back over 4 s,
    // never across the gap: the same calls the gauge's mouse area makes
    Timer {
        interval: 16
        repeat: true
        running: win.mode === "drag" && win.landed && win.volume.ready
        onTriggered: {
            if (!win.ring) {
                win.ring = win.findRing(scene);
                if (!win.ring)
                    return;
                win.ring.press(win.ring.width / 2, 0);
            }
            win.sweep = (win.sweep + 16 / 2000) % 2;
            const v = win.sweep < 1 ? win.sweep : 2 - win.sweep;
            const p = Gauge.pointAt(win.ring.width / 2, win.ring.height / 2, win.ring.radius, v);
            win.ring.drag(p.x, p.y);
            win.steps++;
        }
    }
}
