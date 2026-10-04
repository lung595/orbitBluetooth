import QtQuick
import QtQuick.Shapes

// The sky above the pairing card's horizon: the gradient, two wide lights
// behind the device, three depths of stars, a shooting star now and then
// and two small constellations drawn like a star chart. Fills the card;
// PairingSheet clips it to the card's rounded corners.
Item {
    id: sky

    // The sheet's colours (its `skin`) and its motion (PairingMotion.qml)
    required property var look
    required property var motion
    // Where the planet's limb crosses the card: the sky ends there
    required property real horizon

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: sky.look.skyTop
            }
            GradientStop {
                position: sky.horizon / sky.height
                color: sky.look.skyLow
            }
        }
    }

    // One wide light behind the device, in the accent
    Light {
        width: 420
        squash: 0.8
        x: sky.width / 2 - width / 2
        y: 0
        tint: sky.look.haze
        strength: sky.look.light ? 0.4 : 0.3
    }
    Light {
        width: 260
        x: 170
        y: -120
        tint: sky.look.accent2
        strength: sky.look.light ? 0.16 : 0.18
    }

    // Stars, in three depths that drift a little with the pointer tilt.
    // Fixed scatter (golden ratio), so the sky is the same each time; one in
    // six twinkles.
    Repeater {
        model: [[150, 0.9, 0.4], [70, 1.3, 0.8], [18, 1.9, 1.3]]
        Item {
            id: layerOfStars
            required property var modelData
            required property int index
            anchors.fill: parent
            transform: Translate {
                x: -sky.motion.tiltY * layerOfStars.modelData[2]
                y: sky.motion.tiltX * layerOfStars.modelData[2]
            }
            Repeater {
                model: layerOfStars.modelData[0]
                Rectangle {
                    id: star
                    required property int index
                    readonly property real u: (index * 0.6180339 + 0.137 + layerOfStars.index * 0.29) % 1
                    readonly property real v: (index * 0.7548776 + 0.421 + layerOfStars.index * 0.53) % 1
                    readonly property real base: sky.look.light ? 0.08 + 0.14 * ((index * 0.31) % 1) + 0.12 * layerOfStars.index : 0.14 + 0.32 * ((index * 0.31) % 1) + 0.2 * layerOfStars.index
                    readonly property bool twinkles: index % 6 === 0
                    visible: v * sky.height < sky.horizon - 4
                    x: u * sky.width
                    y: v * sky.height
                    width: layerOfStars.modelData[1]
                    height: width
                    radius: width / 2
                    color: sky.look.ink(1)
                    opacity: twinkles ? base * (0.5 + 0.5 * Math.sin(sky.motion.clock * (1.3 + (index % 5) * 0.35) + index)) : base
                }
            }
        }
    }

    // Now and then a shooting star crosses the sky
    Item {
        id: meteor
        readonly property real period: 7.5
        readonly property int n: Math.floor(sky.motion.clock / period)
        readonly property real p: ((sky.motion.clock % period) / period) / 0.12
        visible: sky.motion.moving && sky.motion.clock > 2.5 && p < 1
        x: 150 + (n * 67) % 160 - p * 170
        y: 18 + (n * 41) % 70 + p * 80
        Rectangle {
            width: 70
            height: 1.4
            radius: 0.7
            transformOrigin: Item.Left
            rotation: -25
            opacity: meteor.p < 0.25 ? meteor.p / 0.25 : 1 - (meteor.p - 0.25) / 0.75
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: sky.look.ink(sky.look.light ? 0.6 : 0.95)
                }
                GradientStop {
                    position: 1
                    color: sky.look.ink(0)
                }
            }
        }
    }

    // Two small constellations, drawn like a star chart
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: sky.look.light ? 0.22 : 0.16
        ShapePath {
            strokeColor: sky.look.ink(1)
            strokeWidth: 0.8
            fillColor: "transparent"
            startX: 34
            startY: 120
            PathLine {
                x: 62
                y: 92
            }
            PathLine {
                x: 96
                y: 104
            }
            PathLine {
                x: 84
                y: 140
            }
            PathLine {
                x: 62
                y: 92
            }
        }
    }
    Repeater {
        model: [[34, 120], [62, 92], [96, 104], [84, 140]]
        Rectangle {
            required property var modelData
            width: 3
            height: 3
            radius: 1.5
            x: modelData[0] - 1.5
            y: modelData[1] - 1.5
            color: sky.look.ink(sky.look.light ? 0.4 : 0.75)
        }
    }
}
