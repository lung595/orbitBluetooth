import QtQuick
import qs.Common
import qs.Widgets
import "../card"

// One row of the group chooser: an output with its picture and name, then a
// tick when it is in, or why it cannot be ticked. A click asks to tick it or,
// when it cannot be, to explain why (value 10): that is the chooser's to do.
// Under the pointer or the keys the row has an eye that hides the output (in
// the Hidden section, brings it back), and a row can be carried off to the
// black hole: the row only reports where the pointer is, the chooser draws
// what is carried and the scene lights the hole.
Rectangle {
    id: item

    // One row of Choice.build: { id, label, icon, ticked, locked, why, caption }
    required property var row
    required property PaperColors paper
    // Under the pointer or the keyboard
    property bool current: false
    // In the Hidden section: nothing is ticked here, the eye brings the output back
    readonly property bool away: row.section === "hidden"
    signal hovered
    signal clicked
    // The eye was pressed
    signal eye
    // The row is carried and the pointer is at `at`, or it was let go there
    // (in the row's own coordinates)
    signal carried(point at)
    signal dropped(point at)

    // What cannot be ticked is faint, a member of the group a little less so
    readonly property real dim: row.why === "" ? 1 : row.locked ? 0.85 : 0.5
    // Ticked now, to be added: a member that is already in the group is settled
    // and stays in the ink, so that only what this adds stands out
    readonly property bool added: row.ticked && !row.locked

    height: 32
    radius: 10
    color: current ? paper.fg(0.08) : "transparent"
    opacity: area.carrying ? 0.45 : 1

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
        anchors.right: eyeButton.visible ? eyeButton.left : parent.right
        anchors.rightMargin: eyeButton.visible ? 4 : 8
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
        id: area
        // Where the press was, to tell a click that wobbles from a row carried off
        property point origin
        property bool carrying: false
        // Set once a row was carried, until the next press: the release that ends it is no click
        property bool moved: false
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: carrying ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onEntered: item.hovered()
        onPressed: mouse => {
            origin = Qt.point(mouse.x, mouse.y);
            moved = false;
        }
        onPositionChanged: mouse => {
            if (!pressed || item.away)
                return;
            if (!carrying && Math.hypot(mouse.x - origin.x, mouse.y - origin.y) > 10) {
                carrying = true;
                moved = true;
            }
            if (carrying)
                item.carried(Qt.point(mouse.x, mouse.y));
        }
        onReleased: mouse => {
            if (carrying)
                item.dropped(Qt.point(mouse.x, mouse.y));
            carrying = false;
        }
        onCanceled: carrying = false
        onClicked: {
            if (!moved)
                item.clicked();
        }
    }
    // Hides the output, or brings it back: only where the pointer or the keys are
    Rectangle {
        id: eyeButton
        objectName: "eyeButton" // found by the tests
        visible: item.current && !area.carrying
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 12
        color: eyeArea.containsMouse ? item.paper.fg(0.16) : item.paper.fg(0.07)
        DankIcon {
            anchors.centerIn: parent
            name: item.away ? "visibility" : "visibility_off"
            size: 14
            color: item.paper.fg(0.85)
        }
        MouseArea {
            id: eyeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.eye()
        }
    }
}
