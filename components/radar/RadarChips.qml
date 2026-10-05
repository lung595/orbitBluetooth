import QtQuick
import qs.Common
import qs.Widgets
import "../card"

// The actions that go with the radar's hero, as a row of glass pills: an icon and
// a few words each, the destructive one tinted red. It only says which was chosen.
Flow {
    id: chips

    // [{ id, icon, label, danger }] (Radar.chips)
    property var model: []
    required property PaperColors paper

    signal chosen(string id)

    spacing: 8

    // How wide the pills are side by side, so the view can centre a short row
    readonly property real natural: {
        let total = 0;
        for (let i = 0; i < pills.count; i++) {
            const pill = pills.itemAt(i);
            total += (pill ? pill.width : 0) + chips.spacing;
        }
        return Math.max(0, total - chips.spacing);
    }

    Repeater {
        id: pills
        model: chips.model
        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property color ink: modelData.danger ? Theme.error : chips.paper.ink

            width: row.implicitWidth + 22
            height: 30
            radius: height / 2
            color: area.containsMouse ? (modelData.danger ? Theme.withAlpha(ink, 0.16) : chips.paper.fg(0.12)) : chips.paper.fg(0.05)
            border.width: 1
            border.color: modelData.danger ? Theme.withAlpha(ink, area.containsMouse ? 0.6 : 0.35) : chips.paper.fg(0.07)
            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

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
