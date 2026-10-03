import QtQuick
import QtQuick.Shapes

// Elliptical radial fade that fills its parent: `color` at `strength` in the
// middle, fully transparent at the edges. One static GPU-filled shape (a
// square radial gradient squashed to the parent's aspect), no layers/effects.
Shape {
    id: v

    property color color: "black"
    property real strength: 1
    property real reach: 1   // gradient radius relative to the half-size

    readonly property real side: Math.max(1, parent ? parent.width : 1)
    readonly property real half: side / 2

    function tone(k) {
        return Qt.rgba(color.r, color.g, color.b, color.a * strength * k);
    }

    width: side
    height: side
    transform: Scale {
        yScale: (v.parent ? v.parent.height : v.side) / v.side
    }
    preferredRendererType: Shape.GeometryRenderer

    ShapePath {
        strokeColor: "transparent"
        strokeWidth: 0
        // Stops approximate an ease-out so the falloff has no visible band
        fillGradient: RadialGradient {
            centerX: v.half
            centerY: v.half
            centerRadius: v.half * v.reach
            focalX: v.half
            focalY: v.half
            GradientStop {
                position: 0
                color: v.tone(1)
            }
            GradientStop {
                position: 0.5
                color: v.tone(0.97)
            }
            GradientStop {
                position: 0.7
                color: v.tone(0.88)
            }
            GradientStop {
                position: 0.83
                color: v.tone(0.62)
            }
            GradientStop {
                position: 0.93
                color: v.tone(0.26)
            }
            GradientStop {
                position: 1
                color: v.tone(0)
            }
        }
        startX: 0
        startY: 0
        PathLine {
            x: v.side
            y: 0
        }
        PathLine {
            x: v.side
            y: v.side
        }
        PathLine {
            x: 0
            y: v.side
        }
        PathLine {
            x: 0
            y: 0
        }
    }
}
