import QtQuick
import qs.Common
import qs.Widgets
import "../card"
import "Radar.js" as Radar

// The actions that go with the radar's hero, as rows of glass pills (Radar.chipRows):
// an icon and a few words each, the destructive one tinted red. Each row is centred.
// It only says which was chosen.
Column {
    id: chips

    // [[{ id, icon, label, danger }]] (Radar.chipRows)
    property var rows: []
    required property PaperColors paper

    signal chosen(string id)

    spacing: Radar.GAP

    Repeater {
        model: chips.rows
        delegate: Row {
            id: line
            required property var modelData
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Radar.GAP

            Repeater {
                model: line.modelData
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property color ink: modelData.danger ? Theme.error : chips.paper.ink

                    width: row.implicitWidth + 22
                    height: Radar.PILL
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
    }
}
