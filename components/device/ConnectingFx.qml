import QtQuick
import QtQuick.Shapes
import qs.Common

// What a connection attempt looks like around a device: a comet circling it
// and two sonar rings leaving it. Everything is a pure function of the
// scene's effects clock, so nothing runs outside an attempt.
Item {
    id: fx
    required property var body

    anchors.fill: parent

    // Connecting: a comet circles the device. Its tapered tail is static
    // geometry (rebuilt only on resize); the effects clock turns it: a
    // steady orbit (1.5 s per turn) plus a slow sway (±22°, 1.8 s), so it
    // speeds up and eases off like a breath. Nothing runs outside a
    // connection attempt.
    Item {
        id: comet
        anchors.centerIn: parent
        width: parent.width + 14
        height: width
        visible: fx.body.phase === "connecting"
        readonly property real r: width / 2 - 2.5
        readonly property real span: 200 * Math.PI / 180   // tail length, radians

        rotation: comet.visible ? (fx.body.scene.fxTime * 240) % 360 : 0

        Item {
            id: sway
            anchors.fill: parent

            rotation: comet.visible && fx.body.scene.motion ? -22 * Math.cos(fx.body.scene.fxTime * Math.PI / 0.9) : 0

            // Tail: a crescent that thins to nothing, brightest at the head
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    fillGradient: ConicalGradient {
                        centerX: comet.width / 2
                        centerY: comet.height / 2
                        angle: 0
                        GradientStop {
                            position: 0
                            color: Theme.withAlpha(fx.body.night.primary, 0.95)
                        }
                        GradientStop {
                            position: 0.3
                            color: Theme.withAlpha(fx.body.night.primary, 0.4)
                        }
                        GradientStop {
                            position: 0.56
                            color: Theme.withAlpha(fx.body.night.primary, 0)
                        }
                        GradientStop {
                            position: 1
                            color: Theme.withAlpha(fx.body.night.primary, 0)
                        }
                    }
                    PathPolyline {
                        path: {
                            const c = comet.width / 2, r = comet.r, n = 28;
                            const outer = [], inner = [];
                            for (let i = 0; i <= n; i++) {
                                const t = i / n;
                                const a = -t * comet.span;           // behind the head
                                const w = 2.6 * Math.pow(1 - t, 1.3) + 0.05;
                                outer.push(Qt.point(c + Math.cos(a) * (r + w / 2), c + Math.sin(a) * (r + w / 2)));
                                inner.push(Qt.point(c + Math.cos(a) * (r - w / 2), c + Math.sin(a) * (r - w / 2)));
                            }
                            return outer.concat(inner.reverse());
                        }
                    }
                }
            }

            // Head: a bright core in a soft glow
            Rectangle {
                width: 10
                height: 10
                radius: 5
                x: comet.width / 2 + comet.r - width / 2
                y: comet.height / 2 - height / 2
                color: Theme.withAlpha(fx.body.night.primary, 0.28)
            }
            Rectangle {
                width: 4.2
                height: 4.2
                radius: 2.1
                x: comet.width / 2 + comet.r - width / 2
                y: comet.height / 2 - height / 2
                color: Qt.lighter(fx.body.night.primary, 1.6)
            }
        }
    }

    // Connecting: two soft sonar rings leave the device one after the
    // other (half a cycle apart), so the attempt reads as a call going
    // out. Pure functions of the effects clock: no animation of their own.
    Repeater {
        model: 2
        Rectangle {
            required property int index
            readonly property real phase: fx.body.phase === "connecting" ? ((fx.body.scene.fxTime / 1.8 + index * 0.5) % 1) : 0
            anchors.centerIn: parent
            width: parent.width * (1.05 + 0.75 * phase)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: fx.body.night.primary
            opacity: fx.body.phase === "connecting" ? 0.5 * Math.pow(1 - phase, 2) : 0
            visible: opacity > 0.01
        }
    }
}
