import QtQuick
import qs.Common
import qs.Widgets

// The pairing card's actions: the main button (Connect, its progress
// while pairing, Done, Try again, Pair anyway) and the quiet links under
// it (Later, Don't offer again, Cancel). PairingSheet places it; each
// part fades in on its own beat of the sheet's entrance.
Item {
    id: actions

    // The sheet (PairingSheet.qml): its phase, motion and actions
    required property var sheet
    // The sheet's colours (its `skin`)
    required property var look

    implicitHeight: links.y + links.height

    // Its own light under it: a glow on the night, a tinted shadow on the pearl
    Light {
        visible: !actions.sheet.busy
        opacity: actions.sheet.stagger(5)
        width: actions.width - 60
        squash: 0.2
        x: 30
        y: mainButton.y + mainButton.height - 10
        tint: actions.look.haze
        strength: actions.look.light ? 0.45 : 0.32
    }

    Rectangle {
        id: mainButton
        x: 16
        opacity: actions.sheet.stagger(5)
        transform: Translate {
            y: (1 - actions.sheet.stagger(5)) * 14
        }
        width: actions.width - 32
        height: 46
        // A rounded rectangle, not a pill: flat and quiet, like the cards
        radius: 12
        readonly property bool quiet: actions.sheet.busy
        color: quiet ? Theme.withAlpha(actions.look.accent, 0.14) : actions.look.accent
        // A hairline of light along the top edge, the only relief it keeps
        Rectangle {
            visible: !mainButton.quiet
            x: parent.radius
            width: parent.width - 2 * parent.radius
            height: 1
            color: Theme.withAlpha("white", actions.look.light ? 0.35 : 0.22)
        }

        // Progress while pairing and connecting, with a sheen running across
        Rectangle {
            visible: actions.sheet.busy
            height: parent.height
            radius: parent.radius
            width: parent.width * (actions.sheet.phase === "pairing" ? 0.38 : actions.sheet.phase === "connecting" ? 0.72 : 0)
            color: Theme.withAlpha(actions.look.accent, 0.35)
            Behavior on width {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }
        }
        // A rounded sheen that stays inside the button and fades at both
        // ends: a clip would cut it square against the rounded corners
        Item {
            anchors.fill: parent
            visible: actions.sheet.busy && actions.sheet.moving
            Rectangle {
                readonly property real t: (actions.sheet.clock * 0.7) % 1
                width: 90
                height: parent.height
                radius: mainButton.radius
                x: t * (parent.width - width)
                opacity: Math.sin(Math.PI * t)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: Theme.withAlpha(actions.look.accent, 0.35)
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: ({
                        "offer": "bluetooth",
                        "pairing": "bluetooth_searching",
                        "connecting": "bluetooth_searching",
                        "done": "check",
                        "confirm": "keyboard",
                        "failed": "refresh"
                    })[actions.sheet.phase] || "bluetooth"
                size: 19
                color: mainButton.quiet ? actions.look.ink(0.92) : actions.look.inkOnAccent
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: ({
                        "offer": "Connect",
                        "pairing": "Pairing",
                        "connecting": "Connecting",
                        "done": "Done",
                        "confirm": "Pair anyway",
                        "failed": "Try again"
                    })[actions.sheet.phase] || ""
                color: mainButton.quiet ? actions.look.ink(0.92) : actions.look.inkOnAccent
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                font.letterSpacing: 0.2
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !actions.sheet.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: actions.sheet.phase === "failed" ? actions.sheet.retry() : actions.sheet.phase === "done" ? actions.sheet.later() : actions.sheet.phase === "confirm" ? actions.sheet.confirmed() : actions.sheet.accepted()
        }
    }

    Row {
        id: links
        anchors.horizontalCenter: parent.horizontalCenter
        y: mainButton.y + mainButton.height + 6
        height: 28
        spacing: 4
        opacity: actions.sheet.stagger(6)

        Quiet {
            visible: actions.sheet.phase === "offer" || actions.sheet.phase === "failed"
            text: "Later"
            onClicked: actions.sheet.later()
        }
        StyledText {
            visible: actions.sheet.phase === "offer" || actions.sheet.phase === "failed"
            text: "·"
            height: 28
            verticalAlignment: Text.AlignVCenter
            color: actions.look.ink(0.35)
        }
        Quiet {
            visible: actions.sheet.phase === "offer" || actions.sheet.phase === "failed"
            text: "Don't offer again"
            onClicked: actions.sheet.ignored()
        }
        Quiet {
            visible: actions.sheet.busy || actions.sheet.phase === "confirm"
            text: "Cancel"
            onClicked: actions.sheet.cancelled()
        }
    }

    // A text link for the secondary answers, brighter under the pointer
    component Quiet: StyledText {
        id: quiet
        signal clicked
        height: 28
        leftPadding: 10
        rightPadding: 10
        verticalAlignment: Text.AlignVCenter
        color: actions.look.ink(quietArea.containsMouse ? 0.92 : 0.5)
        font.pixelSize: Theme.fontSizeSmall
        MouseArea {
            id: quietArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: quiet.clicked()
        }
    }
}
