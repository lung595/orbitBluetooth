import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "Battery.js" as Battery

// The rings just outside a device's disc: the noise-control halo, the
// battery level arc and its breathing glow while charging. When the theme
// has no tone of its own to tell the charge from the primary (the stock Blue
// and Cyan), a bolt rides the head of the arc instead (NightColors.chargingApart).
Item {
    id: arcs
    required property var body

    // The battery arc's colour: the theme's tone at each end of the stretch its
    // level lies on (Battery.stretch), blended, so it drifts from red through
    // amber to green as the level climbs; and its own colour while charging.
    // Never the primary of the group's volume ring, which would pass for it.
    readonly property var tints: ({
            "ok": body.night.success,
            "low": body.night.warning,
            "critical": body.night.error,
            "charging": body.night.charging
        })
    readonly property var stretch: Battery.stretch(body.battery, body.charging)
    readonly property color tint: blend(tints[stretch.from], tints[stretch.to], stretch.t)

    // Two colours blended by hue, saturation and lightness: a blend of red and
    // green in RGB goes muddy in the middle, this one stays as vivid as its ends
    function blend(a, b, t) {
        if (t === 0)
            return a;
        return Qt.hsla(Battery.hueMix(a.hslHue, b.hslHue, t), Battery.along(a.hslSaturation, b.hslSaturation, t), Battery.along(a.hslLightness, b.hslLightness, t), Battery.along(a.a, b.a, t));
    }

    // Noise-control halo: solid = cancelling, dashed = ambient,
    // double = adaptive; nothing when off or unknown. Static art, it only
    // fades when the mode changes.
    Shape {
        id: ancHalo
        anchors.centerIn: parent
        width: parent.width + 17
        height: width
        opacity: arcs.body.ancMode && arcs.body.ancMode !== "off" && !arcs.body.focused ? 1 : 0
        visible: opacity > 0
        preferredRendererType: Shape.CurveRenderer
        readonly property real r: width / 2 - 1.5
        Behavior on opacity {
            enabled: arcs.body.scene.motion
            NumberAnimation {
                duration: 260
            }
        }

        ShapePath {
            strokeColor: Theme.withAlpha(arcs.body.night.primary, arcs.body.ancMode === "nc" ? 0.75 : 0.6)
            strokeWidth: 1.5
            strokeStyle: arcs.body.ancMode === "ambient" ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: [1.5, 3]
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ancHalo.width / 2
                centerY: centerX
                radiusX: ancHalo.r
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 359.9
            }
        }
        ShapePath {
            strokeColor: arcs.body.ancMode === "adaptive" ? Theme.withAlpha(arcs.body.night.primary, 0.35) : "transparent"
            strokeWidth: 1
            fillColor: "transparent"
            PathAngleArc {
                centerX: ancHalo.width / 2
                centerY: centerX
                radiusX: ancHalo.r + 3.5
                radiusY: radiusX
                startAngle: 0
                sweepAngle: 359.9
            }
        }
    }

    // Battery arc (connected devices that report a level)
    Shape {
        anchors.centerIn: parent
        width: parent.width + 7
        height: width
        visible: arcs.body.connected && arcs.body.battery >= 0 && !arcs.body.focused
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.08)
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: (arcs.body.diameter + 7) / 2
                centerY: centerX
                radiusX: centerX - 1
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 359.9
            }
        }
        ShapePath {
            strokeColor: arcs.tint
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: (arcs.body.diameter + 7) / 2
                centerY: centerX
                radiusX: centerX - 1
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * Math.max(0.02, arcs.body.battery / 100)
            }
        }
    }

    // Charging: the level arc breathes (0.15 ↔ 1 every 1.8 s, effects clock)
    Shape {
        id: chargeGlow
        anchors.centerIn: parent
        width: parent.width + 7
        height: width
        visible: arcs.body.charging && !arcs.body.focused
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.withAlpha(arcs.tint, 0.55)
            strokeWidth: 5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: (arcs.body.diameter + 7) / 2
                centerY: centerX
                radiusX: centerX - 1
                radiusY: radiusX
                startAngle: -90
                sweepAngle: 360 * Math.max(0.02, arcs.body.battery / 100)
            }
        }

        opacity: arcs.body.scene.awake && arcs.body.scene.motion ? 0.575 - 0.425 * Math.cos(arcs.body.scene.fxTime * Math.PI / 0.9) : 1
    }

    // Marker for a charge the colour cannot tell: a bolt on a night-sky disc
    // at the head of the level arc. Static (it moves only when the level
    // does), so it costs no frame.
    Rectangle {
        id: marker
        readonly property real orbit: arcs.body.diameter / 2 + 2.5
        readonly property real angle: (-90 + 360 * Math.max(0.02, arcs.body.battery / 100)) * Math.PI / 180
        width: 13
        height: width
        radius: width / 2
        x: arcs.width / 2 + orbit * Math.cos(angle) - width / 2
        y: arcs.height / 2 + orbit * Math.sin(angle) - height / 2
        visible: arcs.body.charging && arcs.body.connected && arcs.body.battery >= 0 && !arcs.body.focused && !arcs.body.night.chargingApart
        color: arcs.body.night.sky
        border.width: 1.5
        border.color: arcs.tint

        DankIcon {
            anchors.centerIn: parent
            name: "bolt"
            size: parent.width - 3
            color: arcs.tint
        }
    }
}
