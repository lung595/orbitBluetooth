pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import "Centre.js" as Centre

// The soft beams from the source to each copy. A small pulse travels along
// them only while sound plays (CentreWatch); the pulse is placed from the
// beams' clock, which the scene's step advances, so there is no animation
// here. The ends follow the bodies, which is what the eye sees fly into place.
Item {
    id: beams

    required property var centre
    readonly property var night: centre.scene.night
    readonly property var origin: centre.bodyOf(centre.source)

    anchors.fill: parent
    opacity: centre.presence

    Repeater {
        model: beams.centre.copies

        delegate: Item {
            id: beam

            required property string modelData
            required property int index
            readonly property var copy: beams.centre.bodyOf(modelData)
            readonly property real dx: copy && beams.origin ? copy.px - beams.origin.px : 0
            readonly property real dy: copy && beams.origin ? copy.py - beams.origin.py : 0
            readonly property var pulse: Centre.pulse(beams.centre.beamTime, index, beams.centre.copies.length)

            visible: !!copy && !!beams.origin
            x: beams.origin ? beams.origin.px : 0
            y: beams.origin ? beams.origin.py : 0
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
}
