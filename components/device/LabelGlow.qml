import QtQuick
import QtQuick.Shapes
import qs.Common

// A soft pool of light behind a label: the name glows slightly and lifts
// off a busy background, without a hard outline. Plain geometry with a
// radial gradient (no layer, no shader), so moving it costs nothing.
Shape {
    id: glow

    property color color: Theme.primary
    property real strength: 0.2          // alpha at the heart of the glow
    property real spanX: 100             // size of the light pool
    property real spanY: 30

    // The gradient is round: draw a square and squash it into an ellipse
    width: spanX
    height: spanX
    transform: Scale {
        origin.x: glow.width / 2
        origin.y: glow.height / 2
        yScale: glow.spanY / Math.max(1, glow.spanX)
    }

    ShapePath {
        strokeWidth: -1
        fillGradient: RadialGradient {
            centerX: glow.width / 2
            centerY: glow.height / 2
            centerRadius: glow.width / 2
            focalX: centerX
            focalY: centerY
            GradientStop {
                position: 0
                color: Theme.withAlpha(glow.color, glow.strength)
            }
            GradientStop {
                position: 0.5
                color: Theme.withAlpha(glow.color, glow.strength * 0.55)
            }
            GradientStop {
                position: 1
                color: Theme.withAlpha(glow.color, 0)
            }
        }
        startX: 0
        startY: 0
        PathLine { x: glow.width; y: 0 }
        PathLine { x: glow.width; y: glow.height }
        PathLine { x: 0; y: glow.height }
        PathLine { x: 0; y: 0 }
    }
}
