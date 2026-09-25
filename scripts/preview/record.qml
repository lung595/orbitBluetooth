import QtQuick
import QtQuick.Window
import qs.Services
import "../../components"

// Records README animations frame by frame, with mock devices and services.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports record.qml -- <scene> <outDir>
// Scenes: beam, gauge, focus, connect. Frames land in <outDir>/f0000.png ...
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string sceneName: args[args.length - 2]
    readonly property string outDir: args[args.length - 1]

    width: 560
    height: 480
    visible: true
    color: "#101114"

    readonly property double t: Date.now()
    readonly property int m: 60000
    readonly property string headset: "58:18:62:3D:72:95"
    readonly property string buds: "6C:4A:85:9E:03:21"

    function makeDevices(budsConnected) {
        return [
            { address: headset, name: "WH-1000XM6", connected: true, paired: true, bonded: true, blocked: false, batteryAvailable: true, battery: 0.54, icon: "audio-headphones" },
            { address: "98:7A:14:22:C1:0E", name: "Xbox Wireless Controller", connected: true, paired: true, bonded: true, blocked: false, batteryAvailable: true, battery: 0.72, icon: "input-gaming" },
            { address: "D4:1A:88:10:5B:77", name: "MX Master 3S", connected: false, paired: true, bonded: true, blocked: false, batteryAvailable: false, battery: 0, icon: "input-mouse" },
            { address: buds, name: "AirPods Pro", connected: budsConnected, paired: budsConnected, bonded: budsConnected, blocked: false, batteryAvailable: budsConnected, battery: 0.86, icon: "audio-headset" },
            { address: "F0:65:AE:31:9C:40", name: "Galaxy Buds3", connected: false, paired: false, bonded: false, blocked: false, batteryAvailable: false, battery: 0, icon: "audio-headset" },
            { address: "3C:8D:20:54:AB:12", name: "Keychron K3", connected: false, paired: true, bonded: true, blocked: false, batteryAvailable: false, battery: 0, icon: "input-keyboard" }
        ];
    }

    // Scene script: [setup delay ms, capture length ms]
    readonly property var timing: ({
            "beam": [1800, 3200],
            "gauge": [3200, 2700],
            "focus": [1500, 2400],
            "connect": [1200, 4600]
        })

    Component.onCompleted: {
        BluetoothService.discovering = false;
        PluginService.globalVars = {
            "orbitBluetooth": {
                "since": { [headset]: t - 42 * m, "98:7A:14:22:C1:0E": t - 95 * m },
                "batteryLog": {
                    [headset]: [[t - 34 * m, 38], [t - 24 * m, 43], [t - 14 * m, 48], [t - 4 * m, 53], [t - 1 * m, 54]],
                    "98:7A:14:22:C1:0E": [[t - 95 * m, 81], [t - 60 * m, 77], [t - 20 * m, 73], [t - 5 * m, 72]]
                },
                "power": {}
            }
        };
        // Beam: start the inner ring rotated so the headset sits beside the host
        if (sceneName === "beam")
            scene.orbitTime = Math.PI / 2 / 0.11;
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 20
        radius: 16
        color: "#07080c"

        OrbitScene {
            id: scene
            anchors.fill: parent
            active: true
            autoScan: false
            cornerRadius: 16
            previewDevices: win.makeDevices(false)
        }
    }

    function body(address) {
        return scene.world.children.find(c => c.address === address) ?? null;
    }

    // --- Capture -------------------------------------------------------------
    property int frame: 0
    property bool capturing: false
    property double captureStart: 0

    function pad(n) {
        return ("0000" + n).slice(-4);
    }

    Timer {
        id: ticker
        interval: 40
        repeat: true
        running: win.capturing
        onTriggered: {
            const n = win.frame++;
            win.contentItem.grabToImage(r => r.saveToFile(win.outDir + "/f" + win.pad(n) + ".png"));
            if (Date.now() - win.captureStart > win.timing[win.sceneName][1]) {
                win.capturing = false;
                quitTimer.start();
            }
        }
    }
    Timer {
        id: quitTimer
        interval: 400
        onTriggered: Qt.quit()
    }

    Timer {
        interval: win.timing[win.sceneName][0]
        running: true
        onTriggered: {
            win.captureStart = Date.now();
            win.capturing = true;
            if (win.sceneName === "focus")
                focusLater.start();
            if (win.sceneName === "connect")
                dragScript.start();
        }
    }

    // Gauge: the card is already open and settled when the capture starts
    Timer {
        interval: 1400
        running: win.sceneName === "gauge"
        onTriggered: scene.focusOn(win.body(win.headset))
    }

    // Focus: open the card a moment into the capture
    Timer {
        id: focusLater
        interval: 300
        onTriggered: scene.focusOn(win.body(win.headset))
    }

    // Connect: drag the earbuds to the ring, release, then "connect"
    property int dragStep: 0
    Timer {
        id: dragScript
        interval: 40
        repeat: true
        onTriggered: {
            const b = win.body(win.buds);
            if (!b)
                return;
            const steps = 34;
            const i = win.dragStep++;
            if (i === 0) {
                win.startX = b.px;
                win.startY = b.py;
                scene.beginDrag(b, Qt.point(b.px, b.py));
                return;
            }
            if (i <= steps) {
                const k = i / steps, e = k * k * (3 - 2 * k);
                const tx = scene.cx - scene.rx * scene.innerNorm * 0.72, ty = scene.cy + scene.ry * 0.12;
                scene.updateDrag(Qt.point(win.startX + (tx - win.startX) * e, win.startY + (ty - win.startY) * e));
                return;
            }
            if (i === steps + 6) {
                scene.endDrag();
                return;
            }
            if (i === steps + 30) {
                scene.previewDevices = win.makeDevices(true);
                scene.refresh();
                stop();
            }
        }
    }
    property real startX: 0
    property real startY: 0
}
