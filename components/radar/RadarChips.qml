import QtQuick
import qs.Common
import qs.Widgets

// The actions that go with the radar's hero, as a row of pills: an icon and a few
// words each, the destructive one in red. It only says which was chosen.
Flow {
    id: chips

    // [{ id, icon, label, danger }] (Radar.chips)
    property var model: []
    required property var night

    signal chosen(string id)

    spacing: 8

    Repeater {
        model: chips.model
        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property color ink: modelData.danger ? chips.night.error : chips.night.ink(0.92)

            width: row.implicitWidth + 22
            height: 30
            radius: height / 2
            color: area.containsMouse ? Theme.withAlpha(ink, 0.2) : chips.night.smoke(0.55)
            border.width: 1
            border.color: Theme.withAlpha(ink, area.containsMouse ? 0.7 : 0.35)

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 6
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: chip.modelData.icon
                    size: 15
                    color: chip.ink
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.label
                    color: chip.ink
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chips.chosen(chip.modelData.id)
            }
        }
    }
}
