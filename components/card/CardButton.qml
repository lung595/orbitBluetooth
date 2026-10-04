import QtQuick
import qs.Common
import qs.Widgets

// A round corner button of the detail card.
Rectangle {
    id: btn
    required property PaperColors paper
    property string icon: ""
    property bool danger: false
    property bool active: false
    signal clicked

    width: 30
    height: 30
    radius: 15
    color: area.containsMouse ? (danger ? Theme.withAlpha(Theme.error, 0.85) : btn.paper.fg(0.12)) : active ? Theme.withAlpha(Theme.primary, 0.22) : btn.paper.fg(0.05)
    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    DankIcon {
        anchors.centerIn: parent
        name: btn.icon
        size: 17
        color: btn.active ? Theme.primary : btn.paper.fg(0.8)
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
