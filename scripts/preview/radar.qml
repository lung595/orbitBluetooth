import QtQuick
import QtQuick.Window
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "../../components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Offscreen renders of the volume radar of a Listen together group: the hero's
// dial big in the middle, the other levels small around it, the hero's actions
// under it. Made-up devices and outputs only.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports radar.qml -- <mode> <out.png>
// Modes: group (the group's level is the hero), bluetooth (a Bluetooth member),
//        wired (a wired output), four (four members, the hero among them)
// Suffixes: "-light" renders with a light theme's accent colors
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string rawMode: args[args.length - 2]
    readonly property var parts: rawMode.split("-")
    readonly property string mode: parts[0]
    readonly property bool light: parts.indexOf("light") > 0
    readonly property string out: args[args.length - 1]

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string speaker: "02:00:00:00:20:01"
    readonly property string dac: "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo"
    readonly property string screen: "alsa_output.pci-0000_00_1f.3.hdmi-stereo"
    readonly property var groups: ({
            "group": [headset, speaker, dac],
            "bluetooth": [headset, speaker, dac],
            "wired": [headset, speaker, dac],
            "four": [headset, speaker, dac, screen]
        })
    readonly property var heroes: ({
            "group": "",
            "bluetooth": speaker,
            "wired": dac,
            "four": screen
        })

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

    FakeRoute {
        id: fakeRoute
        sharing: win.groups[win.mode] || win.groups.group
    }

    readonly property bool landed: scene.centre.grouping === 1 && !scene.centre.travelling
    property bool shown: false

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (win.landed && !win.shown) {
                win.shown = true;
                scene.radar.show(win.heroes[win.mode] ?? "");
                grab.start();
            }
        }
    }
    Timer {
        id: grab
        interval: 1500
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
    // Nothing may keep the render waiting for ever
    Timer {
        interval: 40000
        running: true
        onTriggered: {
            console.warn("radar preview: the group never landed");
            Qt.exit(1);
        }
    }
}
