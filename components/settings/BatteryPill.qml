import QtQuick
import qs.Common
import qs.Widgets
import "BatteryUse.js" as Use

// The battery cost of the setting above it: a pill with its level, then one
// short reason. Static (no timer, no animation); colours come from the theme.
// Beside the pill when there is room for a readable line, under it otherwise,
// so on a narrow page the reason never shrinks to a few words.
Flow {
    id: pill

    required property string forKey

    readonly property var info: Use.use(forKey)
    readonly property color hue: info?.level === "high" ? Theme.error : info?.level === "medium" ? Theme.warning : Theme.primary

    width: parent ? parent.width : 0
    spacing: Theme.spacingS
    // The room the reason has beside the pill
    readonly property real room: width - chip.width - spacing

    Rectangle {
        id: chip
        width: chipRow.implicitWidth + Theme.spacingM
        height: 22
        radius: height / 2
        color: Qt.rgba(pill.hue.r, pill.hue.g, pill.hue.b, 0.15)
        border.width: 1
        border.color: Qt.rgba(pill.hue.r, pill.hue.g, pill.hue.b, 0.4)

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Theme.spacingXS
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "bolt"
                size: 13
                color: pill.hue
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.info?.label ?? ""
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: pill.hue
            }
        }
    }
    StyledText {
        width: pill.room >= 160 ? pill.room : pill.width
        height: Math.max(implicitHeight, chip.height)
        verticalAlignment: Text.AlignVCenter
        text: pill.info?.why ?? ""
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
}
