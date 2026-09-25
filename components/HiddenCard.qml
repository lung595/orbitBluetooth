import QtQuick
import qs.Common
import qs.Widgets
import "DeviceCatalog.js" as Catalog

// What the black hole holds: the hidden devices, each with a "Show" button
// that spits it back into the orbit. Empty, it explains what the hole is for.
Item {
    id: card

    required property var scene
    readonly property var hidden: scene.prefs.hiddenDevices
    readonly property var addresses: Object.keys(hidden).sort((a, b) => card.nameOf(a).localeCompare(card.nameOf(b)))

    readonly property color ink: "#F2F5EE"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.42)

    implicitHeight: content.implicitHeight + Theme.spacingL * 2

    function deviceOf(address) {
        const list = scene.adapter?.devices?.values ?? [];
        for (let i = 0; i < list.length; i++)
            if (list[i].address === address)
                return list[i];
        return scene.previewDevices.find(d => d.address === address) ?? null;
    }
    function nameOf(address) {
        return Catalog.deviceName(deviceOf(address)) || hidden[address] || address;
    }

    // Swallow clicks so they don't reach the scene's "click outside" handler
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.round(width * 0.075)
        color: Qt.rgba(0.075, 0.08, 0.095, 0.86)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)
    }

    Flickable {
        x: Theme.spacingL
        y: Theme.spacingL
        width: parent.width - Theme.spacingL * 2
        height: parent.height - Theme.spacingL * 2
        contentHeight: content.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            width: parent.width
            spacing: Theme.spacingS

            Item {
                width: parent.width
                height: title.implicitHeight

                StyledText {
                    id: title
                    text: "Hidden"
                    color: card.ink
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                }
                StyledText {
                    anchors.left: title.right
                    anchors.leftMargin: Theme.spacingS
                    anchors.baseline: title.baseline
                    text: card.addresses.length ? card.addresses.length + (card.addresses.length > 1 ? " devices" : " device") : ""
                    color: card.muted
                    font.pixelSize: Theme.fontSizeSmall
                }
                // Show all, only when there is more than one
                StyledText {
                    anchors.right: closeBtn.left
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    visible: card.addresses.length > 1
                    text: "Show all"
                    color: allArea.containsMouse ? Theme.primary : Theme.withAlpha(Theme.primary, 0.8)
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    MouseArea {
                        id: allArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.scene.unhideAll()
                    }
                }
                Rectangle {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: closeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                    DankIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 15
                        color: Qt.rgba(1, 1, 1, 0.8)
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.scene.closeHidden()
                    }
                }
            }

            // Empty: what the black hole is for
            StyledText {
                width: parent.width
                visible: card.addresses.length === 0
                topPadding: Theme.spacingXS
                bottomPadding: Theme.spacingXS
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: "Nothing hidden yet.\nDrag a device into the black hole, or right-click it, to keep it out of the orbit. Hidden devices stay connected."
                color: card.muted
                font.pixelSize: Theme.fontSizeSmall
                lineHeight: 1.15
            }

            Repeater {
                model: card.addresses

                Rectangle {
                    id: row
                    required property string modelData
                    readonly property var device: card.deviceOf(modelData)
                    readonly property bool connected: device?.connected ?? false

                    width: content.width
                    height: 44
                    radius: 14
                    color: rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    DeviceGlyph {
                        id: glyph
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        kind: Catalog.resolve(row.device, card.scene.prefs.glyphOverrides)
                        color: row.connected ? Qt.lighter(Theme.primary, 1.12) : Qt.rgba(1, 1, 1, 0.75)
                        stroke: 1.4
                    }
                    Column {
                        anchors.left: glyph.right
                        anchors.leftMargin: 12
                        anchors.right: showBtn.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        StyledText {
                            width: parent.width
                            text: card.nameOf(row.modelData)
                            elide: Text.ElideRight
                            color: card.ink
                            font.pixelSize: Theme.fontSizeSmall + 1
                        }
                        StyledText {
                            text: row.connected ? "Connected" : row.device ? "Nearby" : "Out of range"
                            color: row.connected ? Theme.withAlpha(Theme.primary, 0.85) : card.muted
                            font.pixelSize: Theme.fontSizeSmall - 1
                        }
                    }
                    Rectangle {
                        id: showBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: showRow.implicitWidth + 20
                        height: 28
                        radius: 14
                        color: showArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.32) : Theme.withAlpha(Theme.primary, 0.16)
                        Row {
                            id: showRow
                            anchors.centerIn: parent
                            spacing: 5
                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "visibility"
                                size: 15
                                color: Theme.primary
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Show"
                                color: Theme.primary
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                            }
                        }
                        MouseArea {
                            id: showArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.scene.unhide(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
