import QtQuick
import QtQuick.Shapes
import qs.Common

// A round light, squashed vertically when flatter than wide: the
// gradient reaches zero exactly at the edge, so it never shows a rim.
// The pairing sheet paints its sky glows, atmosphere and button glow
// with it.
Shape {
    id: light

    property color tint
    property real strength: 0.4
    property real squash: 1
    height: light.width
    transform: Scale {
        origin.y: 0
        yScale: light.squash
    }
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillGradient: RadialGradient {
            centerX: light.width / 2
            centerY: light.height / 2
            centerRadius: light.width / 2
            focalX: centerX
            focalY: centerY
            GradientStop {
                position: 0
                color: Theme.withAlpha(light.tint, light.strength)
            }
            GradientStop {
                position: 0.3
                color: Theme.withAlpha(light.tint, light.strength * 0.62)
            }
            GradientStop {
                position: 0.6
                color: Theme.withAlpha(light.tint, light.strength * 0.22)
            }
            GradientStop {
                position: 1
                color: Theme.withAlpha(light.tint, 0)
            }
        }
        PathAngleArc {
            centerX: light.width / 2
            centerY: light.height / 2
            radiusX: light.width / 2
            radiusY: light.height / 2
            sweepAngle: 360
        }
    }
}
