pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import "../together/Member.js" as Member
import "Centre.js" as Centre

// The soft beams from the source to each Bluetooth copy, and a cable to each
// wired one (WiredCable). A small pulse travels along them only while sound
// plays (CentreWatch); the pulse is placed from the beams' clock, which the
// scene's step advances, so there is no animation here. The ends follow the
// discs, which is what the eye sees fly into place.
Item {
    id: beams

    required property var centre
    readonly property var night: centre.scene.night
    // Where the source is: its body, or its spot when it is a wired output
    readonly property var origin: centre.pointOf(centre.source)

    anchors.fill: parent
    opacity: centre.presence

    Repeater {
        model: beams.centre.copies.filter(a => !Member.isWired(a))

        delegate: Item {
            id: beam

            required property string modelData
            readonly property var end: beams.centre.pointOf(modelData)
            readonly property real dx: end && beams.origin ? end.x - beams.origin.x : 0
            readonly property real dy: end && beams.origin ? end.y - beams.origin.y : 0
            // Spread over every copy, wired ones included, so the pulses do not beat together
            readonly property var pulse: Centre.pulse(beams.centre.beamTime, beams.centre.copies.indexOf(modelData), beams.centre.copies.length)

            visible: !!end && !!beams.origin
            x: beams.origin ? beams.origin.x : 0
            y: beams.origin ? beams.origin.y : 0
            width: Math.hypot(dx, dy)
            height: 0
            rotation: Math.atan2(dy, dx) * 180 / Math.PI
            transformOrigin: Item.TopLeft

            // A wide faint band under a thin line, fading out toward the copy
            Rectangle {
                y: -3
                width: parent.width
                height: 6
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Theme.withAlpha(beams.night.primary, 0.1)
                    }
                    GradientStop {
                        position: 1
                        color: Theme.withAlpha(beams.night.primary, 0.02)
                    }
                }
            }
            Rectangle {
                y: -0.75
                width: parent.width
                height: 1.5
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Theme.withAlpha(beams.night.primary, 0.45)
                    }
                    GradientStop {
                        position: 1
                        color: Theme.withAlpha(beams.night.primary, 0.12)
                    }
                }
            }
            Rectangle {
                visible: beams.centre.playing
                x: beam.width * beam.pulse.at - width / 2
                y: -width / 2
                width: 7
                height: width
                radius: width / 2
                color: Theme.withAlpha(beams.night.primary, 0.9 * beam.pulse.alpha)
            }
        }
    }

    // A thin cable to each wired member instead of a beam: they are rows of a
    // list model, so a cable keeps its own tightening when others come and go
    Repeater {
        model: beams.centre.wired

        delegate: WiredCable {
            centre: beams.centre
        }
    }
}
