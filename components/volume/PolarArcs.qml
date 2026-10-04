import QtQuick
import QtQuick.Shapes
import qs.Common
import "Polar.js" as Polar

// The half circles of the scope (PolarScope): for each level a hairline
// track, a faint glow under the lit part, then the lit arc itself. One Shape
// per arc, with the curve renderer: it only redraws when its own level or
// color changes, and an arc that is not there (fewer outputs) is not made
Item {
    id: arcs

    // The scope (PolarScope.qml): its geometry, colors and eased levels
    required property var scope

    anchors.fill: parent

    component Arc: ShapePath {
        id: arcPath
        property real radius: 0
        property real start: 180
        property real sweep: 180
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: arcs.scope.cx + Math.cos(start * Math.PI / 180) * radius
        startY: arcs.scope.cy + Math.sin(start * Math.PI / 180) * radius
        PathAngleArc {
            centerX: arcs.scope.cx
            centerY: arcs.scope.cy
            radiusX: arcPath.radius
            radiusY: arcPath.radius
            startAngle: arcPath.start
            sweepAngle: arcPath.sweep
        }
    }

    // One half circle, or one arc of the outer one: its track (where the
    // level can go), the glow, and the line lit up to its level from the end
    // `slice` (Polar.slices) says
    component Half: Shape {
        id: half
        property real radius: 0
        property var slice: arcs.scope.innerSlice
        property real level: 0
        property bool muted: false
        property color tint: "white"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property var _lit: Polar.arc(slice, level)
        readonly property var _whole: Polar.arc(slice, 1)
        readonly property bool _on: level > 0.001

        Arc {
            radius: half.radius
            start: half._whole.start
            sweep: half._whole.sweep
            strokeWidth: 1
            strokeColor: arcs.scope.trackColor
        }
        Arc {
            radius: half.radius
            start: half._lit.start
            sweep: half._lit.sweep
            strokeWidth: arcs.scope.stroke * 4
            strokeColor: !half._on ? "transparent" : Theme.withAlpha(half.muted ? arcs.scope.mutedColor : half.tint, 0.07)
        }
        Arc {
            radius: half.radius
            start: half._lit.start
            sweep: half._lit.sweep
            strokeWidth: arcs.scope.stroke
            strokeColor: !half._on ? "transparent" : half.muted ? Theme.withAlpha(arcs.scope.mutedColor, 0.6) : half.tint
        }
    }

    Repeater {
        model: arcs.scope.outputs.length
        Half {
            required property int index
            radius: arcs.scope.outer
            slice: arcs.scope.sliceOf(index)
            level: arcs.scope.shownAt(index)
            muted: arcs.scope.output(index).muted
            tint: arcs.scope.output(index).color
        }
    }
    Half {
        radius: arcs.scope.inner
        level: arcs.scope.shownPc
        muted: arcs.scope.pcMuted
        tint: arcs.scope.pcColor
    }
}
