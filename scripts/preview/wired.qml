import QtQuick
import QtQuick.Window
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "../../components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Offscreen renders of a Listen together group with wired outputs (D298): a
// rounded square per output among the planets, the cable to the source, and a
// wired output as the source itself. Made-up devices and outputs only.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports wired.qml -- <mode> <out.png>
// Modes: wired (a headset, a USB interface, a screen on HDMI and a speaker),
//        wiredjack (the three kinds of wired output, a jack among them),
//        wiredsource (the USB interface is the source, the others its copies),
//        wiredpair (a headset and one wired output),
//        wiredmix (the USB interface is the source, a screen on HDMI and a
//        headset its copies: one of each kind to orbit)
// Suffixes: "-loose" catches the cable of an output that has just joined,
// "-reduce" turns Reduce motion on, "-light" renders with a light theme's
// accent colors, "-silent" stops the made-up sound (nothing travels on the
// beams), "-x2" renders at twice the size, "-t<seconds>" stops the copies'
// orbit at that time of its turn (Reduce motion on: 22 puts the first copy at
// the far end, right behind the source; 3 on the horizon)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string rawMode: args[args.length - 2]
    readonly property var parts: rawMode.split("-")
    readonly property string mode: parts[0]
    readonly property bool loose: parts.indexOf("loose") > 0
    readonly property bool reduce: parts.indexOf("reduce") > 0
    readonly property bool light: parts.indexOf("light") > 0
    readonly property bool silent: parts.indexOf("silent") > 0
    // The time the orbit is stopped at (-1: it turns)
    readonly property real stopAt: parts.reduce((at, p) => /^t\d+$/.test(p) ? Number(p.slice(1)) : at, -1)
    readonly property int pixelScale: parts.indexOf("x2") > 0 ? 2 : 1
    readonly property string out: args[args.length - 1]

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string speaker: "02:00:00:00:20:01"
    readonly property string dac: "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo"
    readonly property string screen: "alsa_output.pci-0000_00_1f.3.hdmi-stereo"
    readonly property string jack: "alsa_output.pci-0000_00_1f.3.analog-stereo"
    readonly property var groups: ({
            "wired": [headset, dac, screen, speaker],
            "wiredjack": [headset, jack, dac, screen],
            "wiredsource": [dac, headset, speaker],
            "wiredpair": [headset, dac],
            "wiredmix": [dac, screen, headset]
        })
    readonly property var members: groups[mode] || groups.wired

    width: 560
    height: 480
    visible: true
    color: "#101114"

    Component.onCompleted: {
        if (light) {
            // Accent colors like DMS generates for a light theme
            Theme.isLightMode = true;
            Theme.primary = "#4B6818";
            Theme.primaryText = "#FFFFFF";
            Theme.tertiary = "#386A60";
            Theme.error = "#BA1A1A";
            Theme.errorText = "#FFFFFF";
        }
        SettingsData.reduceMotion = reduce || stopAt >= 0;
        Pipewire.playing = !silent;
        BluetoothService.available = true;
        BluetoothService.enabled = true;
        PluginService.globalVars = State.globals("together", Date.now());
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: 20
        radius: 16
        color: light ? "#d9d4c7" : "#07080c"
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

    // The "-loose" shots start with the Bluetooth ones only: the output joins once they are there
    FakeRoute {
        id: fakeRoute
        sharing: win.loose ? [win.headset, win.speaker] : win.members
    }

    // The group has landed: the camera is there and nothing is on its way
    readonly property bool landed: scene.centre.grouping === 1 && !scene.centre.travelling
    property bool joined: false

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (win.landed && !win.joined) {
                win.joined = true;
                if (win.loose) {
                    fakeRoute.sharing = win.members;
                    grab.interval = 150;
                } else {
                    // The scene settles, with or without motion, and the sun has gone round a little
                    grab.interval = 800;
                }
                if (win.stopAt >= 0) {
                    scene.orbitTime = win.stopAt;
                    scene.wake();
                }
                grab.start();
            }
        }
    }
    Timer {
        id: grab
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        }, Qt.size(win.width * win.pixelScale, win.height * win.pixelScale))
    }
    // Nothing may keep the render waiting for ever
    Timer {
        interval: 40000
        running: true
        onTriggered: {
            console.warn("wired preview: the group never landed");
            Qt.exit(1);
        }
    }
}
