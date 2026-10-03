import QtQuick
import qs.Common
import qs.Widgets

// The middle of the pairing card: what the device offers (tiles), the steps
// while it pairs, or its quick actions once connected. PairingSheet places
// it and fades it in.
Item {
    id: pane

    // The sheet (PairingSheet.qml): its phase, features and actions
    required property var sheet
    // The sheet's colours (its `skin`)
    required property var look

    // What you get (centred when there are fewer than three)
    Row {
        visible: sheet.phase === "offer"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        Repeater {
            model: sheet.features
            Rectangle {
                id: tile
                required property var modelData
                width: (pane.width - 16) / 3
                height: pane.height
                radius: 18
                color: look.tileFill
                border.width: 1
                border.color: look.tileBorder
                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    DankIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: tile.modelData.icon
                        size: 19
                        color: look.accent
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.value
                        color: look.ink(0.92)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.label
                        color: look.ink(0.5)
                        font.pixelSize: Theme.fontSizeSmall - 2
                    }
                }
            }
        }
    }

    // Pairing steps
    Item {
        id: steps
        anchors.fill: parent
        visible: sheet.busy || sheet.phase === "failed"
        readonly property int step: sheet.phase === "connecting" ? 1 : 0
        readonly property var labels: ["Pair", "Connect", "Ready"]

        Rectangle {
            x: parent.width / 6
            width: parent.width * 2 / 3
            y: 15
            height: 2
            radius: 1
            color: look.ink(0.1)
            Rectangle {
                height: parent.height
                radius: 1
                width: parent.width * (steps.step / 2 + (sheet.busy ? 0.25 : 0))
                color: look.accent
            }
        }
        Repeater {
            model: 3
            Column {
                id: stepItem
                required property int index
                readonly property bool passed: index < steps.step
                readonly property bool current: index === steps.step && sheet.phase !== "failed"
                x: steps.width * (index * 2 + 1) / 6 - width / 2
                width: 70
                spacing: 6
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 32
                    height: 32
                    radius: 16
                    color: stepItem.passed ? look.accent : look.planetLow
                    border.width: stepItem.passed ? 0 : 1.5
                    border.color: stepItem.current ? look.accent : sheet.phase === "failed" && stepItem.index === 0 ? Theme.error : look.ink(0.16)
                    DankIcon {
                        anchors.centerIn: parent
                        name: stepItem.passed ? "check" : ["link", "bluetooth", "task_alt"][stepItem.index]
                        size: 16
                        color: stepItem.passed ? look.inkOnAccent : stepItem.current ? look.accent : look.ink(0.4)
                    }
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: steps.labels[stepItem.index]
                    color: stepItem.current ? look.ink(0.92) : look.ink(0.5)
                    font.pixelSize: Theme.fontSizeSmall - 1
                    font.weight: stepItem.current ? Font.DemiBold : Font.Normal
                }
            }
        }
    }

    // Once connected: noise-control mode
    Column {
        anchors.fill: parent
        visible: sheet.phase === "done"
        spacing: 8

        Rectangle {
            visible: sheet.ancModes.length > 0
            width: parent.width
            height: 44
            radius: 22
            color: look.tileFill
            border.width: 1
            border.color: look.tileBorder
            Row {
                anchors.fill: parent
                anchors.margins: 4
                Repeater {
                    model: sheet.ancModes
                    Rectangle {
                        id: modeItem
                        required property var modelData
                        readonly property bool on: modelData.id === sheet.ancMode
                        width: parent.width / sheet.ancModes.length
                        height: parent.height
                        radius: height / 2
                        color: on ? look.accent : "transparent"
                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            DankIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: modeItem.modelData.icon
                                size: 17
                                color: modeItem.on ? look.inkOnAccent : look.ink(0.5)
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modeItem.on
                                text: modeItem.modelData.label
                                color: look.inkOnAccent
                                font.pixelSize: Theme.fontSizeSmall - 1
                                font.weight: Font.DemiBold
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sheet.modeRequested(modeItem.modelData.id)
                        }
                    }
                }
            }
        }
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: sheet.ancModes.length ? "Noise control" : "Ready to use"
            color: look.ink(0.5)
            font.pixelSize: Theme.fontSizeSmall - 1
        }
    }
}
