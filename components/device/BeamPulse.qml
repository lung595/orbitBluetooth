import QtQuick
import qs.Common
import "BeamMotion.js" as Motion

// The Pulse charging beam: three small capsules of light travel along a thin
// rail to the device. No shader, no animation of its own: each capsule's `x`
// is bound to `time` (the scene's 30 Hz effects clock), so a still beam
// (Reduce motion, `running` false) is three capsules at rest and costs no frame.
Item {
    id: pulse

    property bool running: false
    property real time: 0
    // Delay (s) of this beam against its neighbours
    property real offset: 0
    property color startColor: Theme.primary
    property color endColor: Theme.primary

    readonly property real capsuleLength: 16
    readonly property real capsuleHeight: 3

    // The rail the capsules ride
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 1
        color: Theme.withAlpha(pulse.startColor, 0.28)
    }

    Repeater {
        model: 3
        delegate: Rectangle {
            id: capsule
            required property int index
            readonly property real at: Motion.pulseAt(pulse.time, pulse.running, index, pulse.offset)
            x: at * Math.max(0, pulse.width - pulse.capsuleLength)
            y: (pulse.height - height) / 2
            width: pulse.capsuleLength
            height: pulse.capsuleHeight
            radius: height / 2
            opacity: Motion.pulseAlpha(at)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Theme.withAlpha(pulse.endColor, 0)
                }
                GradientStop {
                    position: 1
                    color: pulse.endColor
                }
            }
        }
    }
}
