import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/device"
import "../../components/scene"

// Offscreen render of the charge colour on the night sky: the battery arc
// (with its bolt marker where the theme has no tone of its own for the
// charge) at three levels, and the energy beam, for one stock theme.
// Usage: qml -I imports charge.qml -- <out.png> [blue|bluelight|cyan|cyanlight]
Window {
    id: win
    readonly property string pick: ["blue", "bluelight", "cyan", "cyanlight"].find(n => Qt.application.arguments.includes(n)) ?? ""
    readonly property string out: Qt.application.arguments.find(a => a.endsWith(".png")) || "charge.png"
    readonly property var themes: ({
            "blue": [false, "#42a5f5", "#8ab4f8"],
            "bluelight": [true, "#1976d2", "#42a5f5"],
            "cyan": [false, "#00bcd4", "#4dd0e1"],
            "cyanlight": [true, "#0097a7", "#00bcd4"]
        })
    width: 360
    height: 150
    visible: true
    color: tones.sky

    NightColors {
        id: tones
    }

    Component.onCompleted: {
        if (pick) {
            const [light, primary, secondary] = themes[pick];
            Theme.isLightMode = light;
            Theme.primary = primary;
            Theme.secondary = secondary;
            Theme.tertiary = secondary;
        }
        grab.start();
    }

    // Let the window draw once before the grab
    Timer {
        id: grab
        interval: 700
        onTriggered: win.contentItem.grabToImage(img => {
            img.saveToFile(win.out);
            Qt.quit();
        })
    }

    Repeater {
        model: [18, 55, 92]
        delegate: Item {
            id: slot
            required property int modelData
            required property int index
            x: 20 + index * 110
            y: 10
            width: 90
            height: 90
            QtObject {
                id: fake
                property int battery: slot.modelData
                readonly property bool charging: true
                readonly property bool connected: true
                readonly property bool focused: false
                readonly property string ancMode: ""
                readonly property real diameter: 64
                readonly property var night: tones
                readonly property var scene: ({
                        "motion": false,
                        "awake": false,
                        "fxTime": 0
                    })
            }
            Rectangle {
                anchors.centerIn: parent
                width: fake.diameter
                height: width
                radius: width / 2
                color: tones.connectedFill
            }
            BodyArcs {
                anchors.centerIn: parent
                width: fake.diameter
                height: width
                body: fake
            }
        }
    }

    EnergyBeam {
        x: 20
        y: 108
        width: 320
        height: 36
        amplitude: 2
        wavelength: 38
        time: 1
    }
}
