import QtQuick
import qs.Common

// Charging: an energy beam from the host to the device.
// A softly waving beam (EnergyBeam) with a flare where it leaves the host.
// It follows the scene's effects clock, only while someone is looking.
// Its angle (rotation) and length come from the tether.
Item {
    id: chargeFlow
    required property var body
    // Host-to-device distance, shared with the tether
    required property real dist

    // Above the host's halo, below every device
    parent: body.scene.world
    z: 60
    x: body.scene.cx
    y: body.scene.cy
    // No beam while the host is away at the back (a Listen together has the center)
    opacity: body.charging && !body.leaving && !body.focused && !body.scene.centre.tetherless(body.address) ? (body.scene.focusBody ? 0.15 : 1) : 0
    visible: opacity > 0.01

    readonly property real start: body.scene.coreSize / 2
    readonly property real span: Math.max(0, chargeFlow.dist - start - body.diameter * body.baseScale / 2)
    readonly property bool running: visible && body.scene.awake && body.scene.motion
    readonly property color glow: body.night.primary

    Behavior on opacity {
        NumberAnimation {
            duration: 500
        }
    }

    // The beam itself: waving light strands with pulses flowing toward
    // the device (shaders/beam.frag), animated only while visible
    EnergyBeam {
        x: chargeFlow.start
        y: -height / 2
        width: chargeFlow.span
        height: 44
        amplitude: 2
        wavelength: 38
        running: chargeFlow.running
        time: chargeFlow.body.scene.fxTime
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
