import QtQuick
import QtQuick.Shapes
import qs.Common
import "BeamMotion.js" as Motion
import "HorizonShape.js" as Geo

// The Horizon charging beam: light bent by the device's gravity. A thin arc
// leaves the host and bends toward the device, grains fall along it faster and
// faster, and round the device a thin ring seen almost edge-on carries a knot
// with a short tail. The ring carries flow, never level (the level stays on the
// charge arc), and nothing lit passes 0.7 alpha or 1.3 times the device's
// size, so it never outshines the scene's black hole (D375).
// Shapes for the two static lines, plain items for the moving parts, no
// shader and no animation of its own: every position is bound to `time` (the
// scene's 30 Hz effects clock); a still beam (Reduce motion, `running` false) is
// the grains and the knot at rest and costs no frame.
Item {
    id: horizon

    property bool running: false
    property real time: 0
    // Delay (s) of this beam against its neighbours
    property real offset: 0
    property color startColor: Theme.primary
    property color endColor: Theme.primary
    // The device the ring circles (px), and how far past the link's end its
    // centre is; no radius, no ring
    property real deviceRadius: 0
    property real reach: 0
    // How far (degrees) the link is turned in the scene; the ring turns back by as much
    property real heading: 0

    readonly property real front: Motion.grainFront(time, running, offset)
    readonly property real angle: Motion.knotAngle(time, running, offset)
    readonly property real radius: Geo.ringRadius(deviceRadius)
    readonly property real tilt: Geo.RING_TILT
    // The arc's two halves: the host's colour shifting toward the device's
    readonly property color earlyColor: Theme.withAlpha(Qt.tint(startColor, Theme.withAlpha(endColor, 0.25)), 0.35)
    readonly property color lateColor: Theme.withAlpha(Qt.tint(startColor, Theme.withAlpha(endColor, 0.75)), 0.35)

    // The arc, in two halves so that it shifts from the host's colour to the device's
    Shape {
        y: horizon.height / 2
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: early
            readonly property var control: Geo.controlAt(horizon.width, 0, 0.5)
            readonly property var end: Geo.pointAt(horizon.width, 0.5)
            strokeColor: horizon.earlyColor
            strokeWidth: 1
            fillColor: "transparent"
            PathQuad {
                x: early.end.x
                y: early.end.y
                controlX: early.control.x
                controlY: early.control.y
            }
        }
        ShapePath {
            id: late
            readonly property var control: Geo.controlAt(horizon.width, 0.5, 1)
            readonly property var from: Geo.pointAt(horizon.width, 0.5)
            strokeColor: horizon.lateColor
            strokeWidth: 1
            fillColor: "transparent"
            startX: late.from.x
            startY: late.from.y
            PathQuad {
                x: horizon.width
                y: 0
                controlX: late.control.x
                controlY: late.control.y
            }
        }
    }

    // Grains falling in: the first two in the level's colour
    Repeater {
        model: Geo.GRAINS
        delegate: Rectangle {
            required property int index
            readonly property var g: Geo.grain(horizon.width, horizon.front, index)
            x: g.x - g.r
            y: horizon.height / 2 + g.y - g.r
            width: g.r * 2
            height: width
            radius: g.r
            opacity: g.alpha
            color: index < 2 ? horizon.endColor : Theme.withAlpha(horizon.startColor, 0.8)
        }
    }

    // The ring, centred on the device, and the knot orbiting it
    Item {
        visible: horizon.deviceRadius > 0
        x: horizon.width + horizon.reach
        y: horizon.height / 2
        rotation: Geo.RING_ROTATION * 180 / Math.PI - horizon.heading

        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.withAlpha(horizon.startColor, 0.3)
                strokeWidth: 1.1
                fillColor: "transparent"
                PathAngleArc {
                    radiusX: horizon.radius
                    radiusY: horizon.radius * horizon.tilt
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        Repeater {
            model: Geo.TAIL
            delegate: Rectangle {
                required property int index
                readonly property var t: Geo.tailAt(horizon.radius, horizon.angle, index)
                x: t.x - 0.55
                y: t.y - 0.55
                width: 1.1
                height: width
                radius: 0.55
                opacity: t.alpha
                color: index < 3 ? horizon.endColor : horizon.startColor
            }
        }

        Rectangle {
            readonly property var p: Geo.ringPoint(horizon.radius, horizon.angle)
            x: p.x - 2.2
            y: p.y - 2.2
            width: 4.4
            height: width
            radius: 2.2
            opacity: Geo.knotAlpha(horizon.angle)
            color: horizon.endColor
        }
    }
}
