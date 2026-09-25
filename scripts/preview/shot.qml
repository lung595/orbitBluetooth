import QtQuick
import QtQuick.Window
import qs.Services
import "../../components"

// Offscreen renders for the README, with mock devices and services.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports shot.qml -- <mode> <out.png>
// Modes: orbit, zoom, orbitfocus, desktop, desktopfocus
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]
    readonly property string out: args[args.length - 1]
    readonly property bool glass: mode.startsWith("desktop")
    width: glass ? 760 : (mode === "zoom" ? 900 : 560)
    height: glass ? 560 : (mode === "zoom" ? 700 : mode === "ancfocus" ? 440 : 480)
    visible: true
    color: "#101114"

    readonly property double t: Date.now()
    readonly property int m: 60000

    readonly property var devices: [
        { address: "58:18:62:3D:72:95", name: "WH-1000XM6", connected: true, paired: true, bonded: true, blocked: false, batteryAvailable: true, battery: 0.54, icon: "audio-headphones" },
        { address: "98:7A:14:22:C1:0E", name: "Xbox Wireless Controller", connected: true, paired: true, bonded: true, blocked: false, batteryAvailable: true, battery: 0.72, icon: "input-gaming" },
        { address: "D4:1A:88:10:5B:77", name: "MX Master 3S", connected: false, paired: true, bonded: true, blocked: false, batteryAvailable: false, battery: 0, icon: "input-mouse" },
        { address: "6C:4A:85:9E:03:21", name: "AirPods Pro", connected: false, paired: false, bonded: false, blocked: false, batteryAvailable: false, battery: 0, icon: "audio-headset" },
        { address: "F0:65:AE:31:9C:40", name: "Galaxy Buds3", connected: false, paired: false, bonded: false, blocked: false, batteryAvailable: false, battery: 0, icon: "audio-headset" },
        { address: "3C:8D:20:54:AB:12", name: "Keychron K3", connected: false, paired: true, bonded: true, blocked: false, batteryAvailable: false, battery: 0, icon: "input-keyboard" }
    ]

    Component.onCompleted: {
        BluetoothService.discovering = mode === "orbit";
        PluginService.globalVars = {
            "orbitBluetooth": {
                "since": { "58:18:62:3D:72:95": t - 42 * m, "98:7A:14:22:C1:0E": t - 95 * m },
                "batteryLog": {
                    "58:18:62:3D:72:95": [[t - 34 * m, 38], [t - 24 * m, 43], [t - 14 * m, 48], [t - 4 * m, 53], [t - 1 * m, 54]],
                    "98:7A:14:22:C1:0E": [[t - 95 * m, 81], [t - 60 * m, 77], [t - 20 * m, 73], [t - 5 * m, 72]]
                },
                "power": {},
                // Mock noise-control state for the demo headset
                "anc": {
                    "58:18:62:3D:72:95": {
                        "status": "ready", "live": true, "model": "",
                        "features": { "modes": ["nc", "ambient", "off", "adaptive"], "ambientMax": 20, "levelMode": "ambient", "voice": true, "chat": true },
                        "state": { "mode": mode === "ancfocus" ? "ambient" : "nc", "ambient": 14, "voice": true, "chat": false, "battery": {} }
                    }
                }
            }
        };
    }

    // Synthetic "wallpaper" for the desktop shots (no personal imagery)
    Item {
        anchors.fill: parent
        visible: win.glass
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#2F5D62" }
                GradientStop { position: 0.55; color: "#A7C4A0" }
                GradientStop { position: 1; color: "#E8C07D" }
            }
        }
        Rectangle { x: -120; y: 300; width: 700; height: 420; radius: 210; color: "#5E8B5A"; opacity: 0.55 }
        Rectangle { x: 380; y: 360; width: 600; height: 360; radius: 180; color: "#3D6B45"; opacity: 0.5 }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: win.glass ? 60 : 20
        radius: 16
        color: win.glass ? "transparent" : "#07080c"
        clip: !win.glass

        OrbitScene {
            id: scene
            anchors.fill: parent
            glass: win.glass
            active: true
            autoScan: false
            previewDevices: win.devices
            cornerRadius: win.glass ? 0 : 16
        }
    }

    Timer {
        interval: win.mode === "zoom" ? 14000 : 2600
        running: true
        onTriggered: {
            if (win.mode.endsWith("focus")) {
                for (let i = 0; i < 64; i++) {
                    const b = scene.world.children.find(c => c.address === "58:18:62:3D:72:95");
                    if (b) { scene.focusOn(b); break; }
                }
            }
            grabTimer.interval = win.mode.endsWith("focus") ? 1800 : 50;
            grabTimer.start();
        }
    }
    Timer {
        id: grabTimer
        onTriggered: win.contentItem.grabToImage(r => { r.saveToFile(win.out); Qt.quit(); })
    }
}
