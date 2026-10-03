import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// Scan chip. On glass it is centered, carries its own smoky pill so it
// reads on any wallpaper, and only shows while the widget is in use.
Rectangle {
    required property var scene

    anchors.top: parent.top
    anchors.right: scene.glass ? undefined : parent.right
    anchors.horizontalCenter: scene.glass ? parent.horizontalCenter : undefined
    anchors.margins: Theme.spacingS
    anchors.topMargin: scene.glass ? Math.round(scene.height * 0.07) : Theme.spacingS
    height: Theme.fontSizeSmall + Theme.spacingM
    width: chipRow.implicitWidth + Theme.spacingL
    radius: height / 2
    color: scene.glass ? (chipArea.containsMouse ? Qt.tint(scene.night.smoke(0.78), scene.night.ink(0.06)) : scene.night.smoke(0.6)) : chipArea.containsMouse ? scene.night.ink(0.12) : scene.night.ink(0.06)
    border.width: scene.glass ? 1 : 0
    border.color: scene.night.ink(0.08)
    readonly property bool shown: scene.btOn && !scene.focusBody && !scene.hiddenOpen && (!scene.glass || scene.interacting || scene.discovering)
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        NumberAnimation {
            duration: 220
        }
    }

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: Theme.spacingXS
        Rectangle {
            id: scanDot
            width: Theme.spacingXS + 2
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: scene.discovering ? scene.night.primary : scene.night.ink(0.35)
            // Blinks 1 → 0.25 → 1 every 1.4 s while scanning (effects clock)
            opacity: scene.discovering && scene.active && scene.motion ? 0.25 + 0.75 * Math.abs(1 - (scene.fxTime % 1.4) / 0.7) : 1
        }
        StyledText {
            text: scene.discovering ? "Scanning" : "Scan"
            color: scene.night.ink(0.75)
            font.pixelSize: Theme.fontSizeSmall - 1
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: chipArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: scene.discovering ? scene.stopScan() : scene.startScan()
    }
}
