import QtQuick
import QtQuick.Shapes

// A level drawn as an arc that starts at the top and runs clockwise, over a
// faint full circle. Static art: it is redrawn only when the level changes.
Shape {
    id: arc

    // Radius of the track in px, the level 0..1 and the stroke width
    property real radius: 20
    property real level: 0
    property real lineWidth: 2
    property color trackColor: "transparent"
    property color levelColor: "white"

    width: radius * 2 + lineWidth * 2
    height: width
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: arc.trackColor
        strokeWidth: arc.lineWidth
        fillColor: "transparent"
        PathAngleArc {
            centerX: arc.width / 2
            centerY: centerX
            radiusX: arc.radius
            radiusY: radiusX
            startAngle: -90
            sweepAngle: 359.9
        }
    }
    ShapePath {
        // A level of 0 draws nothing, not the round dot of an empty arc
        strokeColor: arc.level > 0.004 ? arc.levelColor : "transparent"
        strokeWidth: arc.lineWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: arc.width / 2
            centerY: centerX
            radiusX: arc.radius
            radiusY: radiusX
            startAngle: -90
            sweepAngle: 359.9 * Math.min(1, arc.level)
        }
    }
}
