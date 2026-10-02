import QtQuick
import qs.Common
import qs.Widgets

// The level, read in the gap at the bottom of the volume ring. Each digit
// is a strip that rolls like an odometer on a spring, so a step lands with
// a small overshoot you can feel. It drops out of the ring when you start
// adjusting and floats back up as it fades.
// Springs only move while the value changes; at rest nothing runs.
Item {
    id: readout

    property int value: 0 // 0..100
    property bool muted: false
    property bool active: false
    property bool motion: true

    // It sits on the detail card: same ink as the device's name
    readonly property PaperColors paper: PaperColors {}
    readonly property real px: Theme.fontSizeMedium
    // Whole pixels: a fraction lets the next digit bleed in at rest
    readonly property real lineHeight: Math.ceil(probe.implicitHeight)
    readonly property real digitWidth: metrics.advanceWidth

    width: muted ? mutedRow.width : digits.width
    height: lineHeight

    // Font of the digits, measured once: every digit gets the same width so
    // the number does not wobble sideways while it rolls
    StyledText {
        id: probe
        visible: false
        text: "0"
        font.pixelSize: readout.px
        font.weight: Font.Bold
    }
    TextMetrics {
        id: metrics
        font: probe.font
        text: "0"
    }

    // Drops in from the ring, rises back into it when leaving
    opacity: active ? 1 : 0
    visible: opacity > 0.01
    property real lift: active ? 0 : -9
    transform: Translate {
        y: readout.lift
    }
    Behavior on opacity {
        enabled: readout.motion
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    Behavior on lift {
        enabled: readout.motion
        SpringAnimation {
            spring: 4
            damping: 0.3
            epsilon: 0.05
        }
    }

    // One rolling digit
    component Wheel: Item {
        id: wheel
        property int digit: 0
        property bool used: true
        width: used ? readout.digitWidth : 0
        height: readout.lineHeight
        clip: true
        Behavior on width {
            enabled: readout.motion
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Column {
            property real pos: wheel.digit
            y: -pos * readout.lineHeight
            Behavior on pos {
                enabled: readout.motion
                SpringAnimation {
                    spring: 3.4
                    damping: 0.26
                    mass: 0.8
                    epsilon: 0.005
                }
            }
            Repeater {
                model: 10
                StyledText {
                    required property int index
                    width: readout.digitWidth
                    height: readout.lineHeight
                    horizontalAlignment: Text.AlignHCenter
                    text: index
                    font.pixelSize: readout.px
                    font.weight: Font.Bold
                    color: readout.paper.ink
                }
            }
        }
    }

    Row {
        id: digits
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: readout.muted ? 0 : 1
        Wheel {
            digit: Math.floor(readout.value / 100) % 10
            used: readout.value >= 100
        }
        Wheel {
            digit: Math.floor(readout.value / 10) % 10
            used: readout.value >= 10
        }
        Wheel {
            digit: readout.value % 10
        }
        StyledText {
            y: readout.lineHeight - height - 2
            text: "%"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: Theme.primary
        }
    }

    Row {
        id: mutedRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        opacity: readout.muted ? 1 : 0
        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "volume_off"
            size: 14
            color: readout.paper.fg(0.42)
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Muted"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: readout.paper.fg(0.42)
        }
    }
}
