import QtQuick
import QtQuick.Shapes

// A level drawn as an arc that starts at the top and runs clockwise, over a
// faint full circle, with an optional round thumb at its end. Static art: it
// is redrawn only when the level changes.
Shape {
    id: arc

    // Radius of the track in px, the level 0..1 and the stroke width
    property real radius: 20
    property real level: 0
    property real lineWidth: 2
    property color trackColor: "transparent"
    property color levelColor: "white"
    // The thumb's diameter in px (0: none) and color
    property real thumbSize: 0
    property color thumbColor: levelColor

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

    // Sits on the end of the arc, so it follows the level with no animation
    Rectangle {
        // Where the arc ends, in radians from the right, as the arc is drawn
        readonly property real turn: (-90 + 359.9 * Math.min(1, arc.level)) * Math.PI / 180

        visible: arc.thumbSize > 0
        width: arc.thumbSize
        height: width
        radius: width / 2
        color: arc.thumbColor
        x: arc.width / 2 + Math.cos(turn) * arc.radius - width / 2
        y: arc.height / 2 + Math.sin(turn) * arc.radius - height / 2
    }
}
