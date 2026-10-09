import QtQuick
import QtQuick.Shapes
import qs.Common
import "BeamMotion.js" as Motion

// The Chain charging beam: a string of small dots from the host to the device
// and a lit window that runs along it. The dots are one dashed stroke (a single
// static path, not an item per dot); the window is one gradient Rectangle whose
// `x` and `width` are bound to `time`, the scene's 30 Hz effects clock. No
// animation of its own, so a still beam (Reduce motion, `running` false) is the
// window frozen mid-link and costs no frame.
Item {
    id: chain

    property bool running: false
    property real time: 0
    // Delay (s) of this beam against its neighbours
    property real offset: 0
    property color startColor: Theme.primary
    property color endColor: Theme.primary
    property color railColor: Theme.surfaceText

    readonly property real dotSpacing: 9
    readonly property real dotSize: 2.4
    readonly property var lit: Motion.chainWindow(time, running, offset)

    // The unlit dots: a dash as short as the cap is round is a dot
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.withAlpha(chain.railColor, 0.22)
            strokeWidth: chain.dotSize
            capStyle: ShapePath.RoundCap
            strokeStyle: ShapePath.DashLine
            dashPattern: [0.01, chain.dotSpacing / chain.dotSize - 0.01]
            fillColor: "transparent"
            startX: chain.dotSpacing
            startY: chain.height / 2
            PathLine {
                x: Math.max(chain.dotSpacing, chain.width - chain.dotSpacing / 2)
                y: chain.height / 2
            }
        }
    }

    // The lit window: clear at its tail, the level's colour at its head
    Rectangle {
        x: chain.lit[0] * chain.width
        y: (chain.height - height) / 2
        width: (chain.lit[1] - chain.lit[0]) * chain.width
        height: 4
        radius: height / 2
        visible: width > 0.5
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Theme.withAlpha(chain.startColor, 0)
            }
            GradientStop {
                position: 1
                color: chain.endColor
            }
        }
    }
}
