import QtQuick
import qs.Common
import qs.Widgets

// A row of up to three small stat tiles ({ label, value }), e.g.
// "READY AT 18:40 · SPEED +28 %/h · +12% IN 26 min".
Row {
    id: tiles

    property var stats: []
    readonly property var items: (stats || []).slice(0, 3)
    readonly property color ink: "#F2F5EE"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.42)

    visible: items.length > 0
    spacing: Theme.spacingXS

    Repeater {
        model: tiles.items
        Rectangle {
            width: (tiles.width - tiles.spacing * (tiles.items.length - 1)) / tiles.items.length
            height: tileCol.implicitHeight + 10
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.045)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.05)

            Column {
                id: tileCol
                anchors.centerIn: parent
                width: parent.width - 12
                spacing: 1
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.label
                    color: tiles.muted
                    elide: Text.ElideRight
                    font.pixelSize: Math.max(9, Theme.fontSizeSmall - 2)
                    font.letterSpacing: 0.4
                }
                StyledText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.value
                    color: tiles.ink
                    elide: Text.ElideRight
                    font.family: "monospace"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
            }
        }
    }
}
