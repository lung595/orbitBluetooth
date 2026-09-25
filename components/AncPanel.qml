import QtQuick
import qs.Common
import qs.Widgets
import "Anc.js" as Anc

// Noise-control block of the detail card: segmented modes, a level slider
// that only exists in the mode it belongs to, feature chips and per-part
// batteries. Watching the headset while this is shown is what starts the
// helper in the "on demand" engine.
Column {
    id: panel

    required property var scene
    required property string address

    readonly property var info: scene.ancFor(address)
    readonly property var features: info?.features ?? null
    readonly property var st: info?.state ?? ({})
    readonly property var modes: Anc.ordered(features?.modes)
    readonly property bool ready: info?.status === "ready"
    readonly property color ink: "#F2F5EE"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.42)

    spacing: Theme.spacingXS

    property string _watched: ""
    function _rewatch() {
        if (_watched)
            scene.ancWatch(_watched, false);
        _watched = address;
        if (_watched)
            scene.ancWatch(_watched, true);
    }
    onAddressChanged: _rewatch()
    Component.onCompleted: _rewatch()
    Component.onDestruction: if (_watched)
        scene.ancWatch(_watched, false)

    // Status while the helper connects, or why it cannot
    StyledText {
        width: parent.width
        visible: text !== ""
        horizontalAlignment: Text.AlignHCenter
        color: panel.muted
        font.pixelSize: Theme.fontSizeSmall
        text: {
            // A known state stays on screen while a new session reconnects
            if (!panel.info || (panel.info.status === "connecting" && !panel.modes.length))
                return "Reaching noise control…";
            if (panel.info.status === "error")
                return Anc.errorText(panel.info.error);
            return panel.ready && !panel.modes.length ? "No noise control on this model" : "";
        }
    }

    // Segmented modes; the highlight slides under the active one
    Item {
        id: segments
        width: parent.width
        height: 38
        visible: panel.modes.length > 0
        readonly property real segW: width / Math.max(1, panel.modes.length)
        readonly property int current: panel.modes.indexOf(panel.st.mode ?? "")

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.05)
        }
        Rectangle {
            visible: segments.current >= 0
            x: segments.current * segments.segW + 3
            y: 3
            width: segments.segW - 6
            height: parent.height - 6
            radius: height / 2
            color: Theme.withAlpha(Theme.primary, 0.22)
            border.width: 1
            border.color: Theme.withAlpha(Theme.primary, 0.5)
            Behavior on x {
                enabled: panel.scene.motion
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }
        Row {
            anchors.fill: parent
            Repeater {
                model: panel.modes
                Item {
                    required property string modelData
                    required property int index
                    readonly property bool on: index === segments.current
                    width: segments.segW
                    height: segments.height

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        DankIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: Anc.ICONS[modelData]
                            size: 17
                            color: on ? Theme.primary : Qt.rgba(1, 1, 1, 0.7)
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: panel.modes.length <= 3 || on
                            text: Anc.SHORT[modelData]
                            color: on ? panel.ink : Qt.rgba(1, 1, 1, 0.7)
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: on ? Font.DemiBold : Font.Normal
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!parent.on)
                            panel.scene.ancSend(panel.address, "mode", modelData)
                    }
                }
            }
        }
    }

    // Level slider, only in the mode it belongs to (ambient or adaptive)
    Item {
        id: level
        width: parent.width
        height: 22
        readonly property int max: panel.features?.ambientMax ?? 0
        visible: max > 0 && panel.st.mode === panel.features.levelMode
        property real dragValue: -1
        readonly property real value: dragValue >= 0 ? dragValue : (panel.st.ambient ?? 0)

        StyledText {
            id: levelLabel
            anchors.verticalCenter: parent.verticalCenter
            text: panel.features?.levelMode === "adaptive" ? "Noise" : "Ambient"
            color: panel.muted
            font.pixelSize: Theme.fontSizeSmall
        }
        StyledText {
            id: levelValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(level.value)
            color: panel.ink
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
        }
        Item {
            id: track
            anchors.left: levelLabel.right
            anchors.right: levelValue.left
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            height: parent.height
            readonly property real frac: level.max ? level.value / level.max : 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Qt.rgba(1, 1, 1, 0.1)
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * track.frac
                height: 4
                radius: 2
                color: Theme.primary
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * track.frac - width / 2
                width: 14
                height: 14
                radius: 7
                color: panel.ink
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                function valueAt(mx) {
                    return Math.round(Math.max(0, Math.min(1, (mx - 6) / track.width)) * level.max);
                }
                onPressed: m => level.dragValue = valueAt(m.x)
                onPositionChanged: m => level.dragValue = valueAt(m.x)
                // One command on release: the headset is not flooded while dragging
                onReleased: {
                    panel.scene.ancSend(panel.address, "ambient", Math.round(level.dragValue));
                    level.dragValue = -1;
                }
            }
        }
    }

    // Feature chips. The row's visibility comes from these flags, not from
    // the chips' own `visible`: a child of a hidden item reports itself
    // hidden, so the row could never come back once hidden.
    readonly property bool showVoice: (features?.voice ?? false) && st.mode === "ambient"
    readonly property bool showChat: features?.chat ?? false

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingS
        visible: panel.showVoice || panel.showChat

        component Chip: Rectangle {
            id: chip
            property string icon: ""
            property string label: ""
            property bool checked: false
            signal toggled
            width: chipRow.implicitWidth + 20
            height: 28
            radius: 14
            color: checked ? Theme.withAlpha(Theme.primary, 0.22) : Qt.rgba(1, 1, 1, 0.05)
            border.width: checked ? 1 : 0
            border.color: Theme.withAlpha(Theme.primary, 0.5)
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 5
                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: chip.icon
                    size: 15
                    color: chip.checked ? Theme.primary : Qt.rgba(1, 1, 1, 0.7)
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.label
                    color: chip.checked ? panel.ink : Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.toggled()
            }
        }

        Chip {
            id: voiceChip
            visible: panel.showVoice
            icon: "record_voice_over"
            label: "Voice focus"
            checked: panel.st.voice === true
            onToggled: panel.scene.ancSend(panel.address, "voice", checked ? "off" : "on")
        }
        Chip {
            id: chatChip
            visible: panel.showChat
            icon: "forum"
            label: "Conversation"
            checked: panel.st.chat === true
            onToggled: panel.scene.ancSend(panel.address, "chat", checked ? "off" : "on")
        }
    }

    // Per-part batteries (earbuds and case), when the protocol reports them
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingM
        readonly property var parts: Anc.batteryParts(panel.st.battery).filter(p => p.part !== "single")
        visible: parts.length > 0
        Repeater {
            model: parent.parts
            StyledText {
                required property var modelData
                text: modelData.label + " " + modelData.level + "%" + (modelData.charging ? " ⚡" : "")
                color: modelData.level <= 15 ? Theme.error : panel.muted
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
