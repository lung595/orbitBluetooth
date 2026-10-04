import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "../device"

// The stage of the pairing card: the device falling out of the bar along
// a comet trail, caught by its orbit, floating with a moon, sonar rings
// and, once connected, a star burst and its battery ring. PairingSheet
// places it above the horizon; PairingMotion drives every motion (fall,
// arrived, burst, clock) and this only draws them.
Item {
    id: stage

    // The sheet (PairingSheet.qml): its phase and device
    required property var sheet
    // The sheet's colours (its `skin`)
    required property var look
    // The sheet's time and entrance values (PairingMotion.qml)
    required property var motion
    // The ring the entrance flashes (PairingMotion) when the orbit catches
    // the device
    readonly property Item flash: flash

    readonly property real cx: width / 2
    readonly property real deviceY: 86

    // Where the device is now: out of the bar (fall 0), in orbit (1)
    function along(t) {
        const u = 1 - t;
        return Qt.point(u * u * 150 + 2 * u * t * -120, u * u * -210 + 2 * u * t * -20);
    }

    // A thin orbit around the device: back half behind it, front half over it
    component OrbitHalf: Shape {
        property bool front: false
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        rotation: -9
        opacity: stage.motion.arrived
        ShapePath {
            strokeColor: Theme.withAlpha(stage.look.accent, front ? (stage.look.light ? 0.55 : 0.7) : (stage.look.light ? 0.22 : 0.28))
            strokeWidth: front ? 1.3 : 1
            fillColor: "transparent"
            PathAngleArc {
                centerX: stage.cx
                centerY: stage.deviceY + 18
                radiusX: 116
                radiusY: 24
                startAngle: front ? 0 : 180
                sweepAngle: 180
            }
        }
    }
    OrbitHalf {
        z: 0
    }

    // Sonar: rings leaving the device while it waits, faster while pairing
    Repeater {
        model: 2
        Rectangle {
            id: ring
            required property int index
            readonly property real speed: stage.sheet.busy ? 0.75 : 0.38
            readonly property real f: (stage.motion.clock * speed + index * 0.5) % 1
            z: 0
            width: 120
            height: 120
            radius: 60
            x: stage.cx - 60
            y: stage.deviceY - 60 + stage.motion.floatY
            scale: 1 + f * 1.1
            color: "transparent"
            border.width: 1.2 / scale
            border.color: stage.look.accent
            visible: stage.motion.moving && stage.sheet.phase !== "done" && stage.sheet.phase !== "failed"
            opacity: stage.motion.arrived * (1 - f) * (stage.look.light ? 0.35 : 0.45)
        }
    }

    // Comet trail: ghosts of where the device just was
    Repeater {
        model: 9
        Rectangle {
            id: ghost
            required property int index
            readonly property point at: stage.along(Math.max(0, stage.motion.fall - (index + 1) * 0.045))
            z: 0
            width: 30 - index * 2.6
            height: width
            radius: width / 2
            x: stage.cx + at.x - width / 2
            y: stage.deviceY + at.y - height / 2
            color: stage.look.haze
            opacity: stage.motion.fall > 0 && stage.motion.fall < 1 ? (0.4 - index * 0.04) * Math.min(1, (1 - stage.motion.fall) * 4) : 0
        }
    }

    // Flash when the orbit catches it
    Rectangle {
        id: flash
        z: 0
        width: 110
        height: 110
        radius: 55
        x: stage.cx - 55
        y: stage.deviceY - 55
        color: "transparent"
        border.width: 1.5
        border.color: stage.look.accent
        opacity: 0
    }

    Item {
        id: hero
        z: 1
        width: 150
        height: 150
        readonly property point at: stage.along(stage.motion.fall)
        x: stage.cx - width / 2
        y: stage.deviceY - height / 2
        scale: 0.45 + 0.55 * stage.motion.fall
        opacity: Math.min(1, stage.motion.fall * 3)
        transform: [
            Translate {
                x: hero.at.x
                y: hero.at.y + stage.motion.floatY
            },
            Rotation {
                origin.x: 75
                origin.y: 75
                axis.x: 1
                axis.y: 0
                axis.z: 0
                angle: stage.motion.tiltX
            },
            Rotation {
                origin.x: 75
                origin.y: 75
                axis.x: 0
                axis.y: 1
                axis.z: 0
                angle: stage.motion.tiltY
            },
            Rotation {
                origin.x: 75
                origin.y: 75
                angle: stage.motion.floatTurn
            }
        ]

        // Battery once connected: a ring around the device, filling up
        Shape {
            anchors.fill: parent
            visible: stage.sheet.phase === "done" && stage.sheet.battery >= 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: stage.look.ink(0.1)
                strokeWidth: 4
                fillColor: "transparent"
                PathAngleArc {
                    centerX: 75
                    centerY: 75
                    radiusX: 72
                    radiusY: 72
                    sweepAngle: 360
                }
            }
            ShapePath {
                strokeColor: stage.look.accent
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 75
                    centerY: 75
                    radiusX: 72
                    radiusY: 72
                    startAngle: -90
                    sweepAngle: 3.6 * stage.motion.shownBattery
                }
            }
        }

        // Night: the device glows. Pearl: it casts a soft shadow that
        // stretches as it floats up.
        DeviceGlyph {
            id: glyph
            anchors.centerIn: parent
            width: pictureShown ? 128 : 108
            height: width
            kind: stage.sheet.kind
            pictureSource: stage.sheet.pictureSource
            color: stage.look.light ? stage.look.accent : Qt.lighter(stage.look.accent, 1.08)
            stroke: stage.look.light ? 1.35 : 1.15
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: stage.look.light ? Qt.tint(Qt.rgba(0.08, 0.08, 0.14, 1), Theme.withAlpha(stage.look.accent, 0.3)) : stage.look.glow
                shadowBlur: 1
                shadowOpacity: stage.look.light ? 0.3 + stage.motion.floatY * 0.012 : 0.85 - stage.motion.floatY * 0.02
                shadowHorizontalOffset: 0
                shadowVerticalOffset: stage.look.light ? 13 - stage.motion.floatY * 1.2 : 0
            }
        }

        Rectangle {
            visible: stage.sheet.phase === "done" && stage.sheet.battery >= 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 16
            height: 24
            width: batteryText.implicitWidth + 18
            radius: 12
            color: stage.look.accent
            StyledText {
                id: batteryText
                anchors.centerIn: parent
                text: Math.round(stage.motion.shownBattery) + " %"
                color: stage.look.inkOnAccent
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.DemiBold
            }
        }
    }

    OrbitHalf {
        front: true
        z: 2
    }

    // A small moon going round: in front of the device, then behind it
    Rectangle {
        readonly property real a: stage.motion.clock * 0.8 + 0.6
        readonly property real px: 116 * Math.cos(a)
        readonly property real py: 24 * Math.sin(a)
        readonly property real t: -9 * Math.PI / 180
        z: Math.sin(a) > 0 ? 3 : 0.5
        width: 7
        height: 7
        radius: 3.5
        x: stage.cx + px * Math.cos(t) - py * Math.sin(t) - 3.5
        y: stage.deviceY + 18 + px * Math.sin(t) + py * Math.cos(t) - 3.5
        color: stage.look.accent
        opacity: stage.motion.arrived * (Math.sin(a) > 0 ? 1 : 0.45)
    }

    // Connected: a burst of stars out of the device
    Repeater {
        model: 16
        Rectangle {
            id: spark
            required property int index
            readonly property real a: index * Math.PI * 2 / 16 + (index % 2) * 0.2
            readonly property real d: 46 + stage.motion.burst * (60 + (index % 3) * 22)
            z: 3
            visible: stage.motion.burst > 0 && stage.motion.burst < 1
            width: index % 3 === 0 ? 4 : 2.6
            height: width
            radius: width / 2
            x: stage.cx + d * Math.cos(a) - width / 2
            y: stage.deviceY + d * Math.sin(a) * 0.8 - height / 2
            color: index % 2 ? stage.look.accent : stage.look.ink(1)
            opacity: 1 - stage.motion.burst
        }
    }
}
