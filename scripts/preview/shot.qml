import QtQuick
import QtQuick.Window
import qs.Common
import qs.Services
import "../../components"

// Offscreen renders for the README, with mock devices and services.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports shot.qml -- <mode> <out.png>
// Modes: orbit, zoom, orbitfocus, desktop, desktopfocus, ancfocus,
//        buds, budsdock, hole, holetess, hiddencard, hiddenempty, connecting, menu, feed
Window {
    id: win
    readonly property var args: Qt.application.arguments
    // A "-light" suffix renders with a light theme's accent colors
    readonly property string rawMode: args[args.length - 2]
    readonly property bool light: rawMode.endsWith("-light")
    readonly property string mode: rawMode.replace(/-light$/, "")
    readonly property string out: args[args.length - 1]
    readonly property bool glass: mode.startsWith("desktop")
    // Control Center sized shots for the black hole, menu and comet
    readonly property bool compact: ["buds", "budsdock", "hole", "holetess", "hiddencard", "hiddenempty", "connecting", "menu", "feed"].indexOf(mode) >= 0
    width: glass ? 760 : (mode === "zoom" ? 900 : compact ? 540 : 560)
    height: glass ? 560 : (mode === "zoom" ? 700 : mode.startsWith("buds") ? 520 : mode === "ancfocus" ? 540 : compact ? 354 : 480)
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
        { address: "00:11:22:33:44:55", name: "HUAWEI FreeBuds Pro", connected: true, paired: true, bonded: true, blocked: false, batteryAvailable: true, battery: 0.92, icon: "audio-headset" },
        { address: "3C:8D:20:54:AB:12", name: "Keychron K3", connected: false, paired: true, bonded: true, blocked: false, batteryAvailable: false, battery: 0, icon: "input-keyboard" }
    ]

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
        // Two made-up devices already swallowed by the black hole
        if (mode !== "hiddenempty")
            SettingsData.pluginSettings = Object.assign({}, SettingsData.pluginSettings, {
                "hiddenDevices": { "3C:8D:20:54:AB:12": "Keychron K3", "E8:07:BF:6A:19:D4": "JBL Flip 6" },
                "holeStyle": mode === "holetess" ? "tesseract" : "blackhole"
            });
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
                    },
                    // Mock earbuds: case charging; in "budsdock" both buds charge in it
                    "00:11:22:33:44:55": {
                        "status": "ready", "live": true, "model": "",
                        "features": { "modes": ["nc", "adaptive", "ambient", "off"], "ambientMax": 0, "levelMode": "ambient", "voice": true, "chat": false },
                        "state": { "mode": "nc", "ambient": null, "voice": false, "chat": null, "battery": {
                            "left": { "level": mode === "budsdock" ? 64 : 94, "charging": mode === "budsdock" },
                            "right": { "level": mode === "budsdock" ? 58 : 100, "charging": mode === "budsdock" },
                            "case": { "level": 60, "charging": mode !== "budsdock" } } }
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
            const find = a => scene.world.children.find(c => c.address === a);
            if (win.mode.startsWith("buds")) {
                const b = find("00:11:22:33:44:55");
                if (b) scene.focusOn(b);
            } else if (win.mode.endsWith("focus")) {
                const b = find("58:18:62:3D:72:95");
                if (b) scene.focusOn(b);
            } else if (win.mode === "hiddencard" || win.mode === "hiddenempty") {
                scene.openHidden();
            } else if (win.mode === "connecting") {
                const b = find("6C:4A:85:9E:03:21");
                if (b) b.phase = "connecting";
            } else if (win.mode === "menu") {
                const b = find("58:18:62:3D:72:95");
                if (b) scene.openMenu(b, Qt.point(b.px + 14, b.py + 6));
            } else if (win.mode === "feed") {
                const b = find("D4:1A:88:10:5B:77");
                if (b) {
                    scene.beginDrag(b, Qt.point(b.px, b.py));
                    scene.updateDrag(Qt.point(scene.holeX + 26, scene.holeY - 22));
                }
            }
            grabTimer.interval = win.mode.startsWith("buds") ? 2600 : win.mode.endsWith("focus") || win.mode.startsWith("hidden") ? 1800 : win.mode === "connecting" ? 700 : win.mode === "feed" || win.mode === "menu" ? 900 : 50;
            grabTimer.start();
        }
    }
    Timer {
        id: grabTimer
        onTriggered: {
            // Where the drifting black hole ended up (to crop close-ups)
            console.info("hole", scene.holeX + frame.x, scene.holeY + frame.y);
            win.contentItem.grabToImage(r => { r.saveToFile(win.out); Qt.quit(); });
        }
    }
}
