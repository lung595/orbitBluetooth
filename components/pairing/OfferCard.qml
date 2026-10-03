import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../device/DeviceCatalog.js" as Catalog

// Offer card for a newly found, unpaired device
Rectangle {
    id: offer
    required property var scene
    readonly property var device: scene.offerAddress ? scene.deviceMap[scene.offerAddress] ?? null : null
    readonly property bool shown: !!device && !device.connected && !(device.paired || device.bonded) && !scene.focusBody && !scene.hiddenOpen && !scene.dragBody
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: (scene.glass ? Math.round(scene.height * 0.1) : Theme.spacingS) + Theme.spacingXL
    width: Math.min(parent.width - Theme.spacingL * 2, offerRow.implicitWidth + Theme.spacingL * 2)
    height: Theme.fontSizeSmall + Theme.spacingXL
    radius: height / 2
    color: scene.night.smoke(0.8)
    border.width: 1
    border.color: Theme.withAlpha(scene.night.primary, 0.45)
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    z: 20
    Behavior on opacity {
        NumberAnimation {
            duration: 220
        }
    }

    Row {
        id: offerRow
        anchors.centerIn: parent
        spacing: Theme.spacingS
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: offer.device ? Catalog.deviceName(offer.device) + " can be paired" : ""
            color: scene.night.ink(0.85)
            elide: Text.ElideRight
            width: Math.min(implicitWidth, scene.width * 0.5)
            font.pixelSize: Theme.fontSizeSmall - 1
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: connectText.implicitWidth + Theme.spacingL
            height: Theme.fontSizeSmall + Theme.spacingM
            radius: height / 2
            color: connectArea.containsMouse ? Theme.withAlpha(scene.night.primary, 0.4) : Theme.withAlpha(scene.night.primary, 0.25)
            StyledText {
                id: connectText
                anchors.centerIn: parent
                text: "Connect"
                color: scene.night.primary
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Medium
            }
            MouseArea {
                id: connectArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: scene.acceptOffer()
            }
        }
        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "close"
            size: 15
            color: scene.night.ink(0.55)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: scene.dismissOffer()
            }
        }
    }
}
