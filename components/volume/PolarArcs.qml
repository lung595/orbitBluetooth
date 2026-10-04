import QtQuick
import QtQuick.Shapes
import qs.Common
import "Polar.js" as Polar

// The half circles of the scope (PolarScope): a hairline track for each
// level, a faint glow under the lit part, then the lit arc itself. One
// Shape with the curve renderer; it only redraws when a level or a color
// changes
Shape {
    id: arcs

    // The scope (PolarScope.qml): its geometry, colors and eased levels
    required property var scope

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

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

    // Tracks: where each level can go
    Arc {
        radius: arcs.scope.outer
        strokeWidth: 1
        strokeColor: arcs.scope.hasDevice ? arcs.scope.trackColor : "transparent"
    }
    Arc {
        radius: arcs.scope.inner
        strokeWidth: 1
        strokeColor: arcs.scope.trackColor
    }
    // Glow under each lit arc
    Arc {
        radius: arcs.scope.outer
        sweep: Polar.arc("outer", arcs.scope.shownDevice).sweep
        strokeWidth: arcs.scope.stroke * 4
        strokeColor: arcs.scope.hasDevice && arcs.scope.shownDevice > 0.001 ? Theme.withAlpha(arcs.scope.deviceMuted ? arcs.scope.mutedColor : arcs.scope.deviceColor, 0.07) : "transparent"
    }
    Arc {
        radius: arcs.scope.inner
        sweep: Polar.arc("inner", arcs.scope.shownPc).sweep
        strokeWidth: arcs.scope.stroke * 4
        strokeColor: arcs.scope.shownPc > 0.001 ? Theme.withAlpha(arcs.scope.pcMuted ? arcs.scope.mutedColor : arcs.scope.pcColor, 0.07) : "transparent"
    }
    // The levels
    Arc {
        radius: arcs.scope.outer
        sweep: Polar.arc("outer", arcs.scope.shownDevice).sweep
        strokeWidth: arcs.scope.stroke
        strokeColor: arcs.scope.hasDevice && arcs.scope.shownDevice > 0.001 ? (arcs.scope.deviceMuted ? Theme.withAlpha(arcs.scope.mutedColor, 0.6) : arcs.scope.deviceColor) : "transparent"
    }
    Arc {
        radius: arcs.scope.inner
        sweep: Polar.arc("inner", arcs.scope.shownPc).sweep
        strokeWidth: arcs.scope.stroke
        strokeColor: arcs.scope.shownPc > 0.001 ? (arcs.scope.pcMuted ? Theme.withAlpha(arcs.scope.mutedColor, 0.6) : arcs.scope.pcColor) : "transparent"
    }
}
