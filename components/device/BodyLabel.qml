import QtQuick
import qs.Common
import qs.Widgets
import "DeviceCatalog.js" as Catalog
import "../card/Charge.js" as Charge

// The caption next to a device: its name and the time left on its battery
// (or since it connected), over a soft glow that lifts it off the background.
Item {
    id: caption
    required property var body

    // A soft glow behind the name: stronger for connected devices, and for
    // every device while nothing is connected
    LabelGlow {
        x: label.x + label.width / 2 - width / 2
        y: label.y + label.height / 2 - height / 2
        spanX: label.width + 30
        spanY: label.height + 14
        color: caption.body.night.primary
        strength: caption.body.connected || caption.body.hovered ? 0.26 : caption.body.scene.anyConnected ? 0.1 : 0.18
        visible: label.visible && label.opacity > 0
    }

    // Name + connection timer. Orbiting bodies in the upper half put their
    // label above so it never collides with the host core.
    Column {
        id: label
        readonly property bool above: caption.body.inSlot && caption.body.py < caption.body.scene.cy
        readonly property real gap: caption.body.diameter * caption.body.baseScale / 2 + 5
        y: above ? caption.body.height / 2 - gap - height : caption.body.height / 2 + gap
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1
        // A member of a Listen together group is named under the center instead
        visible: (caption.body.scene.prefs.showLabels && caption.body.role === "") || caption.body.hovered || caption.body.dragging
        opacity: caption.body.scene.focusBody || caption.body.scene.hiddenOpen || caption.body.swallowing || caption.body.hideArmed ? 0 : 1

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, caption.body.diameter * 2.1)
            horizontalAlignment: Text.AlignHCenter
            text: caption.body.name
            elide: Text.ElideRight
            color: Qt.rgba(1, 1, 1, caption.body.connected || caption.body.hovered ? 0.95 : caption.body.scene.anyConnected ? 0.68 : 0.85)
            font.pixelSize: Math.max(9, Math.round(caption.body.diameter * 0.2))
            font.weight: caption.body.connected ? Font.Medium : Font.Normal
        }

        // Time left under the name: a bolt and the time to full while
        // charging, an hourglass and the time to empty on battery (the
        // level itself is the arc around the device). Replaces the
        // connection timer, which stays in the detail card.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            readonly property real minutes: caption.body.charging ? (caption.body.charge?.minutesToFull ?? 0) : caption.body.minutesLeft
            visible: minutes > 0

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: caption.body.charging ? "bolt" : "hourglass_bottom"
                size: timeText.font.pixelSize + 1
                color: Theme.withAlpha(caption.body.night.primary, 0.8)
            }
            StyledText {
                id: timeText
                anchors.verticalCenter: parent.verticalCenter
                text: Charge.formatShort(parent.minutes)
                color: Theme.withAlpha(caption.body.night.primary, 0.8)
                font.pixelSize: Math.max(8, Math.round(caption.body.diameter * 0.18))
                font.weight: Font.Medium
                font.features: {
                    "tnum": 1
                }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !caption.body.charging && !(caption.body.minutesLeft > 0) && caption.body.connected && caption.body.scene.sinceFor(caption.body.address) > 0 && !(caption.body.charge?.minutesToFull > 0)
            text: Catalog.formatDuration(caption.body.scene.now - caption.body.scene.sinceFor(caption.body.address))
            color: Theme.withAlpha(caption.body.night.primary, 0.75)
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(caption.body.diameter * 0.17))
        }
    }
}
