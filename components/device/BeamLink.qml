import QtQuick
import "BeamStyle.js" as Style

// The link of a charging beam, in the style the user chose (setting
// `chargeBeamStyle`, IPC `beamStyle`). The one place that picks a style: a
// Loader builds only the active one, so switching it frees the old one at once
// and the others cost nothing. A value that names no style is drawn as
// Filament (BeamStyle.parse).
// The item's width is the link's length and its height the room the style
// may use; the link runs along x from the host to the device.
Item {
    id: link

    property string style: Style.DEFAULT
    // True while the beam is seen, the scene is awake and motion is allowed;
    // otherwise every style shows its still frame
    property bool running: false
    // The scene's effects clock (s)
    property real time: 0
    // Delay (s) of this beam against its neighbours
    property real offset: 0
    property color startColor: "transparent"
    property color endColor: "transparent"
    // Chain and Horizon: the unlit rail and ring (text tone, per the spec)
    property color railColor: "transparent"
    // Filament only: shape of the strands, and white-hot lines on dark backgrounds
    property real amplitude: 3
    property real wavelength: 38
    property real whiteCore: 1
    // Horizon only: the device's radius (px) and how far its centre is past the
    // link's end, for the ring round it; no radius, no ring
    property real deviceRadius: 0
    property real reach: 0
    // How far (degrees) the link is turned in the scene, so that the ring keeps
    // its own tilt on the screen whichever way the link points
    property real heading: 0

    readonly property string shown: Style.parse(style)

    // Nothing is built while the beam is hidden (not charging, card open...)
    Loader {
        anchors.fill: parent
        active: link.visible
        sourceComponent: ({
                "pulse": pulse,
                "chain": chain,
                "horizon": horizon
            })[link.shown] ?? filament
    }

    Component {
        id: pulse
        BeamPulse {
            running: link.running
            time: link.time
            offset: link.offset
            startColor: link.startColor
            endColor: link.endColor
        }
    }

    Component {
        id: chain
        BeamChain {
            running: link.running
            time: link.time
            offset: link.offset
            startColor: link.startColor
            endColor: link.endColor
            railColor: link.railColor
        }
    }

    Component {
        id: horizon
        BeamHorizon {
            running: link.running
            time: link.time
            offset: link.offset
            startColor: link.startColor
            endColor: link.endColor
            railColor: link.railColor
            deviceRadius: link.deviceRadius
            reach: link.reach
            heading: link.heading
        }
    }

    Component {
        id: filament
        EnergyBeam {
            running: link.running
            time: link.time - link.offset
            color: link.startColor
            endColor: link.endColor
            amplitude: link.amplitude
            wavelength: link.wavelength
            whiteCore: link.whiteCore
        }
    }
}
