import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The planet the pairing card's content sits on: the accent glowing along
// its limb (the atmosphere), the planet itself, much wider than the card so
// only its top shows, and the lit limb, bright in the middle and fading
// towards the edges. Fills the card; PairingSheet clips it to the card's
// rounded corners.
Item {
    id: root

    // The sheet's colours (its `skin`)
    required property var look
    // Where the planet's limb crosses the card
    required property real horizon

    // Atmosphere: the accent glowing along the limb
    Light {
        width: 520
        squash: 0.32
        x: root.width / 2 - width / 2
        y: root.horizon - width * squash / 2
        tint: root.look.haze
        strength: 0.55
    }

    Rectangle {
        id: planet
        readonly property real r: 560
        width: r * 2
        height: r * 2
        radius: r
        x: root.width / 2 - r
        y: root.horizon
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.look.planetTop
            }
            GradientStop {
                position: 0.25
                color: root.look.planetLow
            }
        }
    }

    // Lit limb: bright in the middle, fading towards the edges (a
    // horizontal mask, since a stroke cannot take a gradient in Qt 6.9)
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: limbMask
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1.6
                strokeColor: root.look.light ? root.look.accent : Qt.lighter(root.look.accent, 1.2)
                fillColor: "transparent"
                PathAngleArc {
                    centerX: root.width / 2
                    centerY: root.horizon + planet.r
                    radiusX: planet.r
                    radiusY: planet.r
                    startAngle: 240
                    sweepAngle: 60
                }
            }
        }
    }
    Rectangle {
        id: limbMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.02
                color: "transparent"
            }
            GradientStop {
                position: 0.5
                color: "white"
            }
            GradientStop {
                position: 0.98
                color: "transparent"
            }
        }
    }
}
