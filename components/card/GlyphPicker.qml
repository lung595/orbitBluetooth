pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import "../device"
import "../device/Glyphs.js" as Glyphs

// The card's glyph picker: "auto" plus every glyph, eight to a row. A pick
// is saved for the device, answered by the snap sound and a pop of the body.
Flow {
    id: picker
    required property var card

    spacing: 6

    readonly property real tile: Math.floor((width - spacing * 7) / 8)
    readonly property string current: card.scene.prefs.glyphOverrides[card.body?.address] ?? "auto"

    Repeater {
        model: ["auto"].concat(Glyphs.order)

        Rectangle {
            id: cell
            required property string modelData
            readonly property bool selected: picker.current === cell.modelData

            width: picker.tile
            height: width
            radius: width * 0.3
            color: selected ? Theme.withAlpha(Theme.primary, 0.25) : area.containsMouse ? picker.card.paper.fg(0.1) : picker.card.paper.fg(0.04)
            border.width: selected ? 1 : 0
            border.color: Theme.primary

            DeviceGlyph {
                visible: cell.modelData !== "auto"
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: width
                kind: cell.modelData
                stroke: 1.5
                color: cell.selected ? Theme.primary : picker.card.paper.fg(0.8)
            }
            DankIcon {
                visible: cell.modelData === "auto"
                anchors.centerIn: parent
                name: "auto_awesome"
                size: parent.width * 0.5
                color: cell.selected ? Theme.primary : picker.card.paper.fg(0.8)
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    picker.card.scene.prefs.setGlyphOverride(picker.card.body.address, cell.modelData);
                    picker.card.scene.sounds.play("snap");
                    picker.card.body.pop();
                }
            }
        }
    }
}
