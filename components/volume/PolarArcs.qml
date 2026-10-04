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

    // One level's arc: lit up to its level, from the start `part` gives
    // (Polar.arc), or just its hairline track when `track` is set
    component Level: Arc {
        property string part: "outer"
        property real level: 0
        property bool on: true
        property bool muted: false
        property color tint: "white"
        // The soft glow under the lit part, instead of the line itself
        property bool glow: false
        start: Polar.arc(part, level).start
        sweep: Polar.arc(part, level).sweep
        strokeWidth: glow ? arcs.scope.stroke * 4 : arcs.scope.stroke
        strokeColor: !on || level <= 0.001 ? "transparent" : glow ? Theme.withAlpha(muted ? arcs.scope.mutedColor : tint, 0.07) : muted ? Theme.withAlpha(arcs.scope.mutedColor, 0.6) : tint
    }
    component Track: Arc {
        property string part: "outer"
        property bool on: true
        start: Polar.arc(part, 1).start
        sweep: Polar.arc(part, 1).sweep
        strokeWidth: 1
        strokeColor: on ? arcs.scope.trackColor : "transparent"
    }

    readonly property bool _split: scope.split

    // Tracks: where each level can go. Split, the outer one is two quarters
    // that stop a hair short of meeting, so the cut at the top shows
    Track {
        radius: arcs.scope.outer
        on: arcs.scope.hasDevice && !arcs._split
    }
    Track {
        radius: arcs.scope.outer
        part: "d1"
        sweep: Polar.arc("d1", 0.97).sweep
        on: arcs._split
    }
    Track {
        radius: arcs.scope.outer
        part: "d2"
        sweep: Polar.arc("d2", 0.97).sweep
        on: arcs._split
    }
    Track {
        radius: arcs.scope.inner
    }
    // A glow under each lit arc, then the levels themselves
    Level {
        radius: arcs.scope.outer
        part: arcs._split ? "d1" : "outer"
        level: arcs.scope.shownDevice
        on: arcs.scope.hasDevice
        muted: arcs.scope.deviceMuted
        tint: arcs.scope.deviceColor
        glow: true
    }
    Level {
        radius: arcs.scope.outer
        part: "d2"
        level: arcs.scope.shownSecond
        on: arcs._split
        muted: arcs.scope.secondMuted
        tint: arcs.scope.secondColor
        glow: true
    }
    Level {
        radius: arcs.scope.inner
        part: "inner"
        level: arcs.scope.shownPc
        muted: arcs.scope.pcMuted
        tint: arcs.scope.pcColor
        glow: true
    }
    Level {
        radius: arcs.scope.outer
        part: arcs._split ? "d1" : "outer"
        level: arcs.scope.shownDevice
        on: arcs.scope.hasDevice
        muted: arcs.scope.deviceMuted
        tint: arcs.scope.deviceColor
    }
    Level {
        radius: arcs.scope.outer
        part: "d2"
        level: arcs.scope.shownSecond
        on: arcs._split
        muted: arcs.scope.secondMuted
        tint: arcs.scope.secondColor
    }
    Level {
        radius: arcs.scope.inner
        part: "inner"
        level: arcs.scope.shownPc
        muted: arcs.scope.pcMuted
        tint: arcs.scope.pcColor
    }
}
