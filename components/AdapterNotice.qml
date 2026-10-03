import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "Guide.js" as Guide

// Bluetooth off / missing adapter. Neither is a dead end (value 10): with
// no adapter, the GitHub mark opens the guide; if "Turn on" changes nothing
// within 3 s (airplane mode, a switch, rfkill), a note says why.
Column {
    id: notice

    required property var scene

    anchors.horizontalCenter: parent.horizontalCenter
    y: scene.cy + scene.coreSize * 0.5 + 26
    spacing: Theme.spacingS
    visible: !scene.btOn

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: BluetoothService.available ? "Bluetooth is off" : "No Bluetooth adapter"
        color: notice.scene.night.ink(0.6)
        font.pixelSize: Theme.fontSizeSmall
        // Hangs to the right of the text, so the text stays centered
        GuideLink {
            anchors.left: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !BluetoothService.available
            anchor: "bluetooth-is-off"
            size: 13
            color: notice.scene.night.ink(0.6)
            hoverColor: notice.scene.night.primary
        }
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
            onClicked: {
                BluetoothService.setBluetoothEnabled(true);
                stillOff.restart();
            }
        }
    }

    // One shot after a click, never running otherwise
    Timer {
        id: stillOff
        interval: 3000
        onTriggered: {
            if (!notice.scene.btOn)
                notice.scene.explain(Guide.blockedNote());
        }
    }
}
