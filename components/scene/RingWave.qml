import QtQuick
import QtQuick.Shapes

// A ring-shaped wave thrown from the connected orbit: outward when a device
// connects, inward when one leaves. A brief one-shot (0.9 s), so a QML
// animation is fine here (rule 23 only bans durable ones).
Shape {
    id: wave
    required property var scene
    // The orbit's geometry (the scene's, or the profile view's, flatter)
    property var geo: wave.scene
    property bool busy: anim.running
    property bool outward: true
    // Centered on the ring (not the scene), so it grows from the ring's middle
    width: parent.width
    height: wave.geo.ringCy * 2
    preferredRendererType: Shape.CurveRenderer
    opacity: 0
    transformOrigin: Item.Center

    function fire(out) {
        outward = out;
        anim.restart();
    }

    ShapePath {
        strokeColor: wave.scene.night.primary
        strokeWidth: 1.6
        fillColor: "transparent"
        PathAngleArc {
            centerX: wave.scene.cx
            centerY: wave.geo.ringCy
            radiusX: wave.scene.rx * wave.scene.innerNorm
            radiusY: wave.geo.ringRy
            startAngle: 0
            sweepAngle: 360
        }
    }

    ParallelAnimation {
        id: anim
        NumberAnimation {
            target: wave
            property: "scale"
            from: wave.outward ? 0.35 : 1.15
            to: wave.outward ? 1.35 : 0.3
            duration: 900
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            NumberAnimation {
                target: wave
                property: "opacity"
                from: 0
                to: 0.75
                duration: 120
            }
            NumberAnimation {
                target: wave
                property: "opacity"
                to: 0
                duration: 780
                easing.type: Easing.InQuad
            }
        }
    }
}
