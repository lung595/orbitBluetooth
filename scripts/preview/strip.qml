import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/volume"
import "mock"

// Offscreen render of the card's thin volume line (VolumeStrip) with the
// device alone and with two, three and four outputs listening together, from
// a made-up route. Usage: qml -I imports strip.qml -- <out.png> [light]
Window {
    id: win
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
        interval: 500
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
