import QtQuick
import qs.Common
import qs.Widgets
import "../card"

// How long a Speak-to-Chat conversation lasts before the headset ends it by
// itself: four choices in a small segmented control, the current one lit.
// The card shows it only once the headset has said what it is set to.
Column {
    id: row

    required property PaperColors paper
    // Names in the headset's own order (Anc.CHAT_ENDS) and its current value
    required property var names
    property var current: null

    signal picked(int index)

    spacing: 4

    StyledText {
        text: "Conversation ends"
        color: row.paper.fg(0.42)
        font.pixelSize: Theme.fontSizeSmall
    }

    Rectangle {
        width: parent.width
        height: 28
        radius: height / 2
        color: row.paper.fg(0.05)

        Row {
            anchors.fill: parent
            Repeater {
                model: row.names
                Item {
                    id: option
                    required property string modelData
                    required property int index
                    readonly property bool on: index === row.current
                    width: parent.width / row.names.length
                    height: parent.height

                    // Same inset and tint as the noise-control modes above it
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        visible: option.on
                        radius: height / 2
                        color: Theme.withAlpha(Theme.primary, 0.22)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.primary, 0.5)
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: option.modelData.charAt(0).toUpperCase() + option.modelData.slice(1)
                        color: option.on ? row.paper.ink : row.paper.fg(0.7)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: option.on ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!option.on)
                            row.picked(option.index)
                    }
                }
            }
        }
    }
}
