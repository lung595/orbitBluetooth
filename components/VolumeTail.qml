import QtQuick
import qs.Common
import "Volume.js" as Volume

// The comet tail behind the volume ring's moon: a trail of fading beads
// along the ring, from the moon back to where the tail's end still is. The
// end chases the moon (VolumeFx.follow), so a fast move leaves a long tail
// that shrinks into the moon when it stops. Hidden when the end has caught up.
Item {
    id: tail

    property real centerX: 0
    property real centerY: 0
    property real radius: 0
    property real level: 0 // where the moon is, 0..1
    property real end: 0 // where the tail ends, 0..1

    readonly property NightColors night: NightColors {}
    readonly property real span: (level - end) * Volume.sweep // degrees
    readonly property int beads: 14

    visible: Math.abs(span) > 1.5

    Repeater {
        model: tail.beads
        Rectangle {
            required property int index
            // 0 at the moon, 1 at the end of the tail
            readonly property real f: (index + 1) / tail.beads
            readonly property real a: (Volume.start + Volume.sweep * tail.level - tail.span * f) * Math.PI / 180
            readonly property real d: 1.5 + 5.5 * (1 - f)
            x: tail.centerX + Math.cos(a) * tail.radius - d / 2
            y: tail.centerY + Math.sin(a) * tail.radius - d / 2
            width: d
            height: d
            radius: d / 2
            // White hot at the head, the theme's color as it cools
            color: Qt.lighter(tail.night.ringAccent, f < 0.4 ? 1.9 : 1.5)
            opacity: Math.pow(1 - f, 1.4) * Math.min(1, Math.abs(tail.span) / 12)
        }
    }
}
