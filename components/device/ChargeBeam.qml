import QtQuick
import qs.Common
import "BeamMotion.js" as Motion

// Charging: an energy beam from the host to the device, in the style of the
// setting `chargeBeamStyle` (BeamLink picks it), with a flare where it leaves
// the host. It follows the scene's effects clock, only while someone is
// looking; with Reduce motion it is a still frame.
// Its angle (rotation) and length come from the tether.
Item {
    id: chargeFlow
    required property var body
    // Host-to-device distance, shared with the tether
    required property real dist

    // Above the host's halo, below every device
    parent: body.scene.world
    z: 60
    readonly property var host: body.scene.centre.host
    x: host.x
    y: host.y
    // No beam for a member of a Listen together (it has the center)
    opacity: body.charging && !body.leaving && !body.focused && !body.scene.centre.tetherless(body.address) ? (body.scene.cardOpen ? 0.15 : 1) : 0
    visible: opacity > 0.01

    readonly property real start: body.scene.coreSize / 2 * host.scale
    readonly property real radius: body.diameter * body.baseScale / 2
    readonly property real span: Math.max(0, chargeFlow.dist - start - radius)
    readonly property bool running: visible && body.scene.awake && body.scene.motion
    // The beam shifts from the host's colour to the charge arc's
    readonly property color glow: body.night.primary

    Behavior on opacity {
        NumberAnimation {
            duration: 500
        }
    }

    // The beam itself, 44 px high on the axis; only the active style is built
    // (BeamLink), and none while the beam is hidden
    BeamLink {
        x: chargeFlow.start
        y: -height / 2
        width: chargeFlow.span
        height: 44
        style: chargeFlow.body.scene.beamStyle
        running: chargeFlow.running
        time: chargeFlow.body.scene.fxTime
        offset: Motion.deviceOffset(chargeFlow.body.address)
        startColor: chargeFlow.glow
        endColor: chargeFlow.body.night.charging
        deviceRadius: chargeFlow.radius
        reach: chargeFlow.radius
        heading: chargeFlow.rotation
    }

    // Source flare where the beam leaves the host
    Rectangle {
        x: chargeFlow.start - width / 2
        y: -height / 2
        width: 12
        height: width
        radius: width / 2
        color: Theme.withAlpha(chargeFlow.glow, 0.35)
        Rectangle {
            anchors.centerIn: parent
            width: 4
            height: 4
            radius: 2
            color: "white"
        }
    }
}
