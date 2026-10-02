import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// Bluetooth off / missing adapter
Column {
    required property var scene

    anchors.horizontalCenter: parent.horizontalCenter
    y: scene.cy + scene.coreSize * 0.5 + 26
    spacing: Theme.spacingS
    visible: !scene.btOn

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: BluetoothService.available ? "Bluetooth is off" : "No Bluetooth adapter"
        color: scene.night.ink(0.6)
        font.pixelSize: Theme.fontSizeSmall
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: BluetoothService.available
        width: onText.implicitWidth + Theme.spacingXL
        height: Theme.fontSizeSmall + Theme.spacingL
        radius: height / 2
        color: onArea.containsMouse ? Theme.withAlpha(scene.night.primary, 0.35) : Theme.withAlpha(scene.night.primary, 0.2)
        StyledText {
            id: onText
            anchors.centerIn: parent
            text: "Turn on"
            color: scene.night.primary
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
        }
        MouseArea {
            id: onArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: BluetoothService.setBluetoothEnabled(true)
        }
    }
}
