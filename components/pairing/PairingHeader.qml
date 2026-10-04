import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets

// The top strip of the pairing card: what is happening (Pairing mode,
// Connected…), how many devices wait behind this one, and the close button
// with the time left to answer as a ring around it. PairingSheet places it
// across the card's width; each part fades in on the first beat of the
// sheet's entrance.
Item {
    id: header

    // The sheet (PairingSheet.qml): its phase, queue, time left and actions
    required property var sheet
    // The sheet's colours (its `skin`) and motion (PairingMotion.qml)
    required property var look
    required property var motion

    Rectangle {
        id: statusPill
        x: 16
        y: 16
        opacity: header.motion.stagger(0)
        height: 28
        width: statusRow.implicitWidth + 22
        radius: 14
        color: header.look.light ? Qt.rgba(1, 1, 1, 0.7) : header.look.ink(0.06)
        border.width: 1
        border.color: header.look.ink(header.look.light ? 0.07 : 0.1)

        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 7
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 3.5
                color: header.sheet.phase === "failed" ? Theme.error : header.look.accent
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: ({
                        "offer": "Pairing mode",
                        "pairing": "Pairing…",
                        "connecting": "Connecting…",
                        "done": "Connected",
                        "failed": "Not connected"
                    })[header.sheet.phase] || ""
                color: header.look.ink(0.85)
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Medium
            }
        }
    }

    Rectangle {
        visible: header.sheet.stacked > 0
        anchors.right: closeButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: closeButton.verticalCenter
        height: 24
        width: moreText.implicitWidth + 16
        radius: 12
        color: Theme.withAlpha(header.look.accent, 0.16)
        StyledText {
            id: moreText
            anchors.centerIn: parent
            text: "+" + header.sheet.stacked
            color: header.look.accent
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: Font.DemiBold
        }
    }

    // Close, with the time left as a ring around it
    Item {
        id: closeButton
        opacity: header.motion.stagger(0)
        width: 32
        height: 32
        x: header.width - width - 14
        y: 14

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: header.look.light ? Qt.rgba(1, 1, 1, closeArea.containsMouse ? 0.95 : 0.7) : header.look.ink(closeArea.containsMouse ? 0.14 : 0.06)
        }
        Shape {
            anchors.fill: parent
            visible: header.sheet.phase === "offer"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: header.look.accent
                strokeWidth: 2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 16
                    centerY: 16
                    radiusX: 15
                    radiusY: 15
                    startAngle: -90
                    sweepAngle: 360 * header.sheet.life
                }
            }
        }
        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: 17
            color: header.look.ink(0.8)
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: header.sheet.later()
        }
    }
}
