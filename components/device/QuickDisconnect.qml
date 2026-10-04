import QtQuick
import qs.Widgets

// The small close button on a connected device, shown on hover: one click
// disconnects it.
Rectangle {
    id: button
    required property var body

    width: Math.round(button.body.diameter * 0.36)
    height: width
    radius: width / 2
    x: button.body.width * (0.5 + 0.36 * button.body.baseScale) - width / 2
    y: button.body.height * (0.5 - 0.36 * button.body.baseScale) - height / 2
    z: 2
    color: closeArea.containsMouse ? button.body.night.error : Qt.rgba(0.1, 0.1, 0.12, 0.95)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.15)
    opacity: button.body.scene.prefs.quickDisconnect && button.body.connected && (button.body.hovered || closeArea.containsMouse) && !button.body.dragging ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }

    DankIcon {
        anchors.centerIn: parent
        name: "close"
        size: parent.width * 0.7
        color: closeArea.containsMouse ? button.body.night.errorText ?? "white" : Qt.rgba(1, 1, 1, 0.8)
    }

    MouseArea {
        id: closeArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.body.scene.startDisconnect(button.body)
    }
}
