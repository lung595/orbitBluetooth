import QtQuick
import qs.Common
import qs.Widgets
import "../centre/Centre.js" as Centre

// What a device looks like at rest: the halo, the disc, its glyph (or
// picture), the rings and the charging badge. `visual` in DeviceBody scales
// and fades it as a whole.
Item {
    id: face
    required property var body

    anchors.fill: parent

    // The halo, the glow and the disc: what a copy of a group gives up while it
    // is behind the source (body.solid, which changes every frame, so it is not
    // on the parts' own opacities, whose Behaviors would restart endlessly)
    Item {
        anchors.fill: parent
        opacity: face.body.solid

        // Halo for connected devices
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.55
            height: width
            radius: width / 2
            color: Theme.withAlpha(face.body.night.primary, 0.07)
            opacity: face.body.connected && !face.body.focused ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                }
            }
        }

        // Soft glow behind the glyph while it floats above the focus card
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.9
            height: width
            radius: width / 2
            color: Theme.withAlpha(face.body.night.primary, 0.05)
            opacity: face.body.focused ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }
        }

        Rectangle {
            id: disc
            anchors.fill: parent
            radius: width / 2
            opacity: face.body.focused ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: 260
                }
            }
            color: face.body.connected ? face.body.night.connectedFill : face.body.night.whiteBodies ? Qt.rgba(1, 1, 1, face.body.dormant ? 0.35 : 0.72) : face.body.scene.glass ? Qt.rgba(0.05, 0.06, 0.08, face.body.dormant ? 0.5 : 0.6) : Qt.rgba(1, 1, 1, face.body.dormant ? 0.05 : 0.085)
            border.width: 1
            border.color: face.body.armed && face.body.holding ? Theme.withAlpha(face.body.night.error, 0.8) : face.body.armed ? Theme.withAlpha(face.body.night.primary, 0.9) : face.body.connected ? face.body.night.connectedEdge : Qt.rgba(1, 1, 1, face.body.dormant ? 0.11 : 0.17)

            Behavior on color {
                ColorAnimation {
                    duration: 350
                }
            }
        }
    }

    DeviceGlyph {
        anchors.centerIn: parent
        width: parent.width * (pictureShown ? 0.92 : 0.52)
        height: width
        kind: face.body.kind
        imageSource: face.body.scene.prefs.imageFor(face.body.device)
        pictureSource: face.body.picture ? face.body.picture.image : ""
        color: face.body.focused ? face.body.paper.ink : face.body.connected ? face.body.night.memberInk(face.body.solid) : face.body.night.whiteBodies ? face.body.night.bodyMuted : Qt.rgba(1, 1, 1, 0.86)
        opacity: Centre.inkOf(face.body.solid)
        stroke: face.body.focused ? 1.05 : 1.5
        // A copy's colour follows its depth every frame: only the others change
        // it in steps
        Behavior on color {
            enabled: face.body.role !== "copy"
            ColorAnimation {
                duration: 300
            }
        }
    }

    BodyArcs {
        anchors.fill: parent
        body: face.body
    }

    // Charging badge
    Rectangle {
        width: Math.round(face.body.diameter * 0.34)
        height: width
        radius: width / 2
        x: parent.width * 0.86 - width / 2
        y: parent.height * 0.86 - height / 2
        color: face.body.night.primary
        border.width: 2
        border.color: Qt.rgba(0.04, 0.045, 0.06, 1)
        visible: face.body.charging && !face.body.focused

        DankIcon {
            anchors.centerIn: parent
            name: "bolt"
            size: parent.width * 0.78
            color: face.body.night.primaryText ?? "black"
        }
    }
}
