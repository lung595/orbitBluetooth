import QtQuick
import qs.Common
import qs.Widgets
import "../card"

// One row of the group chooser: an output with its picture and name, then a
// tick when it is in, or why it cannot be ticked. A click asks to tick it or,
// when it cannot be, to explain why (value 10): that is the chooser's to do.
Rectangle {
    id: item

    // One row of Choice.build: { id, label, icon, ticked, locked, why, caption }
    required property var row
    required property PaperColors paper
    // Under the pointer or the keyboard
    property bool current: false
    signal hovered
    signal clicked

    // What cannot be ticked is faint, a member of the group a little less so
    readonly property real dim: row.why === "" ? 1 : row.locked ? 0.85 : 0.5
    // Ticked now, to be added: a member that is already in the group is settled
    // and stays in the ink, so that only what this adds stands out
    readonly property bool added: row.ticked && !row.locked

    height: 32
    radius: 10
    color: current ? paper.fg(0.08) : "transparent"

    DankIcon {
        id: icon
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        name: item.row.icon
        size: 16
        opacity: item.dim
        color: item.added ? Theme.primary : item.paper.fg(0.75)
    }
    StyledText {
        anchors.left: icon.right
        anchors.leftMargin: 9
        anchors.right: trailing.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: item.row.label
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
        opacity: item.dim
        color: item.added ? Theme.primary : item.paper.ink
        font.pixelSize: Theme.fontSizeSmall
        font.weight: item.added ? Font.DemiBold : Font.Normal
    }
    // Why it cannot be ticked, and the tick
    Row {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        StyledText {
            visible: item.row.caption !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: item.row.caption
            wrapMode: Text.NoWrap
            color: item.paper.fg(0.6)
            font.pixelSize: Theme.fontSizeSmall - 1
        }
        DankIcon {
            visible: item.row.ticked
            anchors.verticalCenter: parent.verticalCenter
            name: "check"
            size: 14
            color: item.added ? Theme.primary : item.paper.fg(0.5)
        }
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: item.hovered()
        onClicked: item.clicked()
    }
}
