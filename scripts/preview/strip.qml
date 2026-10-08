import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/volume"
import "mock"

// Offscreen render of the card's thin volume line (VolumeStrip) with the
// device alone and with two, three and four outputs listening together, from
// a made-up route. Usage: qml -I imports strip.qml -- <out.png> [light]
// Bench modes (no picture, keeps running): "rest" holds the lines still,
// "keyloop" steps every output's volume as a held volume key does (30 Hz
// for 1 s, then 1 s of rest), so the tint binding is re-read on each step.
Window {
    id: win
    readonly property bool rest: Qt.application.arguments.includes("rest")
    readonly property bool keyloop: Qt.application.arguments.includes("keyloop")
    readonly property var routes: []
    readonly property bool light: Qt.application.arguments.includes("light")
    readonly property string out: Qt.application.arguments.find(a => a.endsWith(".png")) || "strip.png"
    width: 380 + 32
    height: 4 * 40 + 5 * 12
    visible: true
    color: light ? "#d9d4c7" : "#2b3a24"

    Component.onCompleted: if (light) {
        Theme.isLightMode = true;
        Theme.primary = "#4C6619";
        Theme.secondary = "#5A4E7C";
        Theme.tertiary = "#2F6A5E";
        Theme.surfaceContainer = "#F1EFE6";
    }

    Column {
        x: 16
        y: 12
        spacing: 12
        // How many outputs share the sound in each line (0: the device alone)
        Repeater {
            model: [0, 2, 3, 4]
            Item {
                id: one
                required property int modelData
                width: 380
                height: 40
                FakeRoute {
                    id: route
                    Component.onCompleted: win.routes.push(route)
                    focusDevice: ({
                            "address": "02:00:00:00:10:06",
                            "name": "Headset",
                            "icon": "audio-headphones"
                        })
                    sharing: ["02:00:00:00:10:06", "02:00:00:00:20:01", "02:00:00:00:20:02", "02:00:00:00:20:03"].slice(0, one.modelData)
                }
                TwoLevels {
                    id: levels
                    route: route
                    dev: route.find("02:00:00:00:10:06")
                }
                VolumeStrip {
                    anchors.fill: parent
                    levels: levels
                }
            }
        }
    }
    Timer {
        property int step: 0
        interval: 33
        repeat: true
        running: win.keyloop
        onTriggered: {
            step = (step + 1) % 60;
            if (step >= 30)
                return;
            const v = 0.3 + 0.4 * Math.abs(Math.sin(step / 10));
            for (const r of win.routes)
                for (const n of [r.otherOne, r.otherTwo, r.otherThree, r.shared, r.copyOne])
                    n.audio.volume = v;
        }
    }
    Timer {
        interval: 500
        running: !win.rest && !win.keyloop
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
