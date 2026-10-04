import QtQuick
import qs.Common
import qs.Widgets

// The small round button in the corner of the card's scope that folds it
// back into the thin volume line (menus only). It sits inside a ScopeScreen
// and takes its colors from that screen's paper or night palette.
Rectangle {
    id: fold
    required property var scope
    signal clicked

    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: scope.margin + Theme.spacingXS
    width: 24
    height: 24
    radius: 12
    color: area.containsMouse ? (scope.light ? scope.paper.fg(0.1) : scope.night.ink(0.12)) : "transparent"

    DankIcon {
        anchors.centerIn: parent
        name: "expand_less"
        size: 18
        color: fold.scope.light ? fold.scope.paper.fg(area.containsMouse ? 0.9 : 0.5) : fold.scope.night.ink(area.containsMouse ? 0.95 : 0.5)
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: fold.clicked()
    }
}
