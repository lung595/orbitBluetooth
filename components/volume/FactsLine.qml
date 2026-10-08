import QtQuick
import qs.Common
import qs.Widgets

// What the output is, in one line, with an ⓘ that unfolds the rest (D260).
// Shows what it is given (TwoLevels.factsLine / factsRows); the colors come
// from the surface it sits on, so the card's paper and the scope's night
// screen both fit. Nothing runs here.
Item {
    id: line
    objectName: "factsLine" // found by the offscreen previews

    // TwoLevels: factsLine, factsRows, unfolded, refreshFacts()
    required property var source
    property color ink: Theme.surfaceText
    property color muted: Theme.surfaceVariantText
    // A pill behind the line (over the scope), or none (on the card)
    property color fill: "transparent"
    property color stroke: "transparent"
    // The details are unfolded: one state in the source, so every screen
    // that shows the output unfolds together and the graph is read once
    property bool expanded: source.unfolded
    // The details unfold above the line (over the scope's foot) or below it
    property bool up: false
    // A click: the caller keeps itself open a while longer
    signal touched

    readonly property bool shown: source.factsLine !== ""
    implicitWidth: Math.max(pill.width, details.visible ? details.width : 0)
    visible: shown
    implicitHeight: details.visible ? details.height + Theme.spacingXS + pill.height : pill.height

    // The unfolded facts, one label and value per row
    Rectangle {
        id: details
        visible: line.expanded && line.source.factsRows.length > 0
        y: line.up ? 0 : pill.height + Theme.spacingXS
        anchors.horizontalCenter: parent.horizontalCenter
        width: grid.width + Theme.spacingM * 2
        height: grid.height + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: line.fill
        border.width: 1
        border.color: line.stroke

        Column {
            id: grid
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: line.source.factsRows
                Row {
                    required property var modelData
                    spacing: Theme.spacingM
                    StyledText {
                        width: 84
                        text: parent.modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        color: line.muted
                    }
                    StyledText {
                        text: parent.modelData.text
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: line.ink
                    }
                }
            }
        }
    }

    Rectangle {
        id: pill
        y: line.up && details.visible ? details.height + Theme.spacingXS : 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: summary.width + Theme.spacingM * 2
        height: summary.height + 4
        radius: height / 2
        color: line.fill
        border.width: line.fill.a > 0 ? 1 : 0
        border.color: line.stroke

        Row {
            id: summary
            anchors.centerIn: parent
            spacing: Theme.spacingXS
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: line.source.factsLine
                font.pixelSize: Theme.fontSizeSmall
                color: line.muted
            }
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: line.source.factsRows.length > 0
                name: "info"
                size: 14
                color: more.containsMouse || line.expanded ? line.ink : line.muted
                MouseArea {
                    id: more
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        line.source.unfolded = !line.source.unfolded;
                        line.source.refreshFacts();
                        line.touched();
                    }
                }
            }
        }
    }
}
