import QtQuick
import QtQuick.Window
import qs.Common
import qs.Services
import "../../components"
import "../../components/Guide.js" as Guide

// Offscreen renders for the README, with mock devices and services.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports shot.qml -- <mode> <out.png>
// Modes: orbit, zoom, orbitfocus, volumefocus (the card with its two volumes), desktop, desktopfocus, ancfocus,
//        buds, budsdock, hole, holetess, hiddencard, hiddenempty, connecting, menu, feed,
//        btblocked (Turn on did nothing: note), noadapter
Window {
    id: win
    readonly property var args: Qt.application.arguments
    // Suffixes: "-light" renders with a light theme's accent colors,
    // "-bright" puts the desktop shots on a pale, busy wallpaper (the
    // hardest case for label contrast), "-none" disconnects every device,
    // "-fit" sizes the window like the bar popout (grows to the open card),
    // "-cc" like the Control Center tile (same, from a smaller minimum),
    // "-follow" gives the headset no level of its own (no absolute volume),
    // "-fold" starts the card's volumes folded, as in the menus, and
    // "-unfold" shows them unfolded there
    readonly property string rawMode: args[args.length - 2]
    readonly property var flags: rawMode.split("-")
    readonly property bool bright: flags.indexOf("bright") > 0
    readonly property bool light: flags.indexOf("light") > 0
    readonly property bool none: flags.indexOf("none") > 0
    readonly property bool cc: flags.indexOf("cc") > 0
    readonly property bool fit: flags.indexOf("fit") > 0 || cc
    readonly property bool follow: flags.indexOf("follow") > 0
    readonly property bool fold: flags.indexOf("fold") > 0 || unfold
    readonly property bool unfold: flags.indexOf("unfold") > 0
    readonly property string mode: flags[0]
    readonly property string out: args[args.length - 1]
    readonly property bool glass: mode.startsWith("desktop")
    // Control Center sized shots for the black hole, menu and comet
    readonly property bool compact: ["buds", "budsdock", "hole", "holetess", "hiddencard", "hiddenempty", "connecting", "menu", "feed"].indexOf(mode) >= 0
    width: glass ? 760 : (mode === "zoom" ? 900 : compact ? 540 : 560)
    height: fit ? Math.max(cc ? 314 : 440, Math.ceil(scene.focusFitHeight)) + 40 : glass ? 560 : (mode === "zoom" ? 700 : mode.startsWith("buds") ? 520 : mode === "ancfocus" ? 540 : compact ? 354 : 480)
    visible: true
    color: "#101114"

    readonly property double t: Date.now()
    readonly property int m: 60000

    readonly property var devices: (none ? allDevices.map(d => Object.assign({}, d, {
                connected: false
            })) : allDevices)
    readonly property var allDevices: [
        {
            address: "02:00:00:00:10:06",
            name: "WH-1000XM6",
            connected: true,
            paired: true,
            bonded: true,
            blocked: false,
            batteryAvailable: true,
            battery: 0.54,
            icon: "audio-headphones"
        },
        {
            address: "98:7A:14:22:C1:0E",
            name: "Xbox Wireless Controller",
            connected: true,
            paired: true,
            bonded: true,
            blocked: false,
            batteryAvailable: true,
            battery: 0.72,
            icon: "input-gaming"
        },
        {
            address: "D4:1A:88:10:5B:77",
            name: "MX Master 3S",
            connected: false,
            paired: true,
            bonded: true,
            blocked: false,
            batteryAvailable: false,
            battery: 0,
            icon: "input-mouse"
        },
        {
            address: "6C:4A:85:9E:03:21",
            name: "AirPods Pro",
            connected: false,
            paired: false,
            bonded: false,
            blocked: false,
            batteryAvailable: false,
            battery: 0,
            icon: "audio-headset"
        },
        {
            address: "F0:65:AE:31:9C:40",
            name: "Galaxy Buds3",
            connected: false,
            paired: false,
            bonded: false,
            blocked: false,
            batteryAvailable: false,
            battery: 0,
            icon: "audio-headset"
        },
        {
            address: "00:11:22:33:44:55",
            name: "HUAWEI FreeBuds Pro",
            connected: true,
            paired: true,
            bonded: true,
            blocked: false,
            batteryAvailable: true,
            battery: 0.92,
            icon: "audio-headset"
        },
        {
            address: "3C:8D:20:54:AB:12",
            name: "Keychron K3",
            connected: false,
            paired: true,
            bonded: true,
            blocked: false,
            batteryAvailable: false,
            battery: 0,
            icon: "input-keyboard"
        }
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
                "hiddenDevices": {
                    "3C:8D:20:54:AB:12": "Keychron K3",
                    "E8:07:BF:6A:19:D4": "JBL Flip 6"
                },
                "holeStyle": mode === "holetess" ? "tesseract" : "blackhole",
                "desktopBackdrop": bright ? 50 : 72
            });
        BluetoothService.discovering = mode === "orbit";
        // btblocked: "Turn on" pressed, nothing changed (note shown);
        // noadapter: no adapter at all
        BluetoothService.available = mode !== "noadapter";
        BluetoothService.enabled = mode !== "btblocked" && mode !== "noadapter";
        PluginService.globalVars = {
            "orbitBluetooth": {
                "since": {
                    "02:00:00:00:10:06": t - 42 * m,
                    "98:7A:14:22:C1:0E": t - 95 * m
                },
                "batteryLog": {
                    "02:00:00:00:10:06": [[t - 34 * m, 38], [t - 24 * m, 43], [t - 14 * m, 48], [t - 4 * m, 53], [t - 1 * m, 54]],
                    "98:7A:14:22:C1:0E": [[t - 95 * m, 81], [t - 60 * m, 77], [t - 20 * m, 73], [t - 5 * m, 72]]
                },
                "power": {},
                // Mock noise-control state for the demo headset
                "anc": {
                    "02:00:00:00:10:06": {
                        "status": "ready",
                        "live": true,
                        "model": "",
                        "features": {
                            "modes": ["nc", "ambient", "off", "adaptive"],
                            "ambientMax": 20,
                            "levelMode": "ambient",
                            "voice": true,
                            "chat": true
                        },
                        "state": {
                            "mode": mode === "ancfocus" ? "ambient" : "nc",
                            "ambient": 14,
                            "voice": true,
                            "chat": false,
                            "battery": {}
                        }
                    },
                    // Mock earbuds: case charging; in "budsdock" both buds charge in it
                    "00:11:22:33:44:55": {
                        "status": "ready",
                        "live": true,
                        "model": "",
                        "features": {
                            "modes": ["nc", "adaptive", "ambient", "off"],
                            "ambientMax": 0,
                            "levelMode": "ambient",
                            "voice": true,
                            "chat": false
                        },
                        "state": {
                            "mode": "nc",
                            "ambient": null,
                            "voice": false,
                            "chat": null,
                            "battery": {
                                "left": {
                                    "level": mode === "budsdock" ? 64 : 94,
                                    "charging": mode === "budsdock"
                                },
                                "right": {
                                    "level": mode === "budsdock" ? 58 : 100,
                                    "charging": mode === "budsdock"
                                },
                                "case": {
                                    "level": 60,
                                    "charging": mode !== "budsdock"
                                }
                            }
                        }
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
                GradientStop {
                    position: 0
                    color: "#2F5D62"
                }
                GradientStop {
                    position: 0.55
                    color: "#A7C4A0"
                }
                GradientStop {
                    position: 1
                    color: "#E8C07D"
                }
            }
        }
        Rectangle {
            x: -120
            y: 300
            width: 700
            height: 420
            radius: 210
            color: "#5E8B5A"
            opacity: 0.55
        }
        Rectangle {
            x: 380
            y: 360
            width: 600
            height: 360
            radius: 180
            color: "#3D6B45"
            opacity: 0.5
        }

        // Pale, busy variant: sky, clouds and bright patches under the labels
        Item {
            anchors.fill: parent
            visible: win.bright
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#DCE8F2"
                    }
                    GradientStop {
                        position: 0.6
                        color: "#F4EFE4"
                    }
                    GradientStop {
                        position: 1
                        color: "#C9D9B8"
                    }
                }
            }
            Repeater {
                model: [[40, 60, 260, 90], [420, 30, 300, 110], [120, 420, 340, 120], [520, 380, 260, 150], [300, 220, 200, 70]]
                Rectangle {
                    x: modelData[0]
                    y: modelData[1]
                    width: modelData[2]
                    height: modelData[3]
                    radius: height / 2
                    color: index % 2 ? "#FFFFFF" : "#8FA7B8"
                    opacity: 0.8
                }
            }
        }
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
            audioRoute: fakeRoute
            foldVolume: win.fold
            volumeUnfolded: win.unfold
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
                if (b)
                    scene.focusOn(b);
            } else if (win.mode.endsWith("focus")) {
                const b = find("02:00:00:00:10:06");
                if (b)
                    scene.focusOn(b);
            } else if (win.mode === "hiddencard" || win.mode === "hiddenempty") {
                scene.openHidden();
            } else if (win.mode === "btblocked") {
                scene.explain(Guide.blockedNote());
            } else if (win.mode === "connecting") {
                const b = find("6C:4A:85:9E:03:21");
                if (b)
                    b.phase = "connecting";
            } else if (win.mode === "menu") {
                const b = find("02:00:00:00:10:06");
                if (b)
                    scene.openMenu(b, Qt.point(b.px + 14, b.py + 6));
            } else if (win.mode === "feed") {
                const b = find("D4:1A:88:10:5B:77");
                if (b) {
                    scene.beginDrag(b, Qt.point(b.px, b.py));
                    scene.updateDrag(Qt.point(scene.holeX + 26, scene.holeY - 22));
                }
            }
            grabTimer.interval = win.mode.startsWith("buds") ? 2600 : win.mode === "volumefocus" ? 1760 : win.mode.endsWith("focus") || win.mode.startsWith("hidden") ? 1800 : win.mode === "connecting" ? 700 : win.mode === "feed" || win.mode === "menu" || win.mode === "btblocked" ? 900 : 50;
            grabTimer.start();
        }
    }
    // What the daemon's AudioRoute gives the card, made up: the headset
    // (02:00:00:00:10:06) at 62 % with this PC at 85 %
    QtObject {
        id: fakeRoute
        readonly property var headset: ({
                "device": scene.focusBody ? scene.focusBody.device : null,
                "absolute": win.follow ? 0 : 1,
                "sink": {
                    "name": "bluez_output.02_00_00_00_10_06.1",
                    "audio": {
                        "volume": win.follow ? 0.85 : 0.62,
                        "muted": false
                    }
                },
                "pc": win.follow ? null : {
                    "audio": {
                        "volume": 0.85,
                        "muted": false
                    }
                }
            })
        function find(address) {
            return address === "02:00:00:00:10:06" ? headset : null;
        }
        function deviceNode(dev) {
            return dev && dev.absolute === 1 ? dev.sink : null;
        }
        function pcNode(dev) {
            return dev ? (dev.pc || (dev.absolute === 1 ? null : dev.sink)) : null;
        }
        function mainPart(address) {
            return "device";
        }
        function stepNode(node, dir) {
        }
        function setLevel(which, arg, address) {
            return "";
        }
        function toggleMute(address) {
            return "pc";
        }
    }
    readonly property var soundFrame: ({
            "l": [0.92, 0.85, 0.8, 0.72, 0.66, 0.62, 0.55, 0.5, 0.44, 0.4, 0.33, 0.28, 0.22, 0.18, 0.12, 0.08],
            "r": [0.9, 0.8, 0.7, 0.66, 0.58, 0.5, 0.47, 0.4, 0.36, 0.3, 0.26, 0.2, 0.16, 0.12, 0.08, 0.05]
        })
    // Focused shots: once the card is up, a made-up sound fills its scope
    Timer {
        running: win.mode.endsWith("focus")
        interval: 2600 + 1400
        onTriggered: {
            const seek = item => {
                if (item.objectName === "cardScope")
                    return item;
                for (const c of item.children) {
                    const r = seek(c);
                    if (r)
                        return r;
                }
                return null;
            };
            const scope = seek(win.contentItem);
            if (scope && scope.visible)
                scope.simulate(win.soundFrame, 0.7);
        }
    }
    Timer {
        id: grabTimer
        onTriggered: {
            // Where the drifting black hole ended up (to crop close-ups)
            console.info("hole", scene.holeX + frame.x, scene.holeY + frame.y);
            win.contentItem.grabToImage(r => {
                r.saveToFile(win.out);
                Qt.quit();
            });
        }
    }
}
