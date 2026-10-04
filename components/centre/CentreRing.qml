import QtQuick
import qs.Common
import qs.Widgets
import "MasterVolume.js" as Master
import "../volume"

// The ring around the source at the centre: the general volume of the group
// (D284). It fills clockwise from the top, where a speaker says what it is
// and mutes the group when pressed, and a round thumb sits at the end of the
// level; the level is written out while the pointer is on the ring and for a
// moment after every change (D295). Drag along the ring or turn the wheel over
// it to move every member's level together, keeping the gaps between them. A
// wheel over the planet itself does the same (BodyWheel).
Item {
    id: ring

    required property var centre
    readonly property var volume: centre.volume
    readonly property var night: centre.scene.night
    // Where the pointer grabs the ring: a band around it, easier to hit than
    // the thin line itself
    readonly property real band: 11
    readonly property real lineWidth: 3
    // The speaker at the top of the ring and the chip behind it, which hides
    // the line under it
    readonly property real iconSize: Math.max(10, Math.round(centre.scene.coreSize * 0.22))
    readonly property real chipSize: iconSize + 8
    readonly property string glyph: Master.icon(volume.level, volume.muted)
    // The thumb waits until the arc has left the speaker
    readonly property real thumbSize: volume.level * 2 * Math.PI * radius > chipSize ? lineWidth * 3 : 0
    // Where the pointer last read the ring (0..1) while it is held; empty
    // (NaN) until the first reading of a press
    property real held: NaN

    // What the ring says: the level, or that the group is muted; empty while
    // there is no sound to read. A change of it, whoever made it (a drag, the
    // wheel, a volume key), writes the level out for `holdTime` ms. `seen` is
    // what was read last, so that reading it for the first time is no change.
    readonly property string reading: volume.ready ? (volume.muted ? "Muted" : Math.round(volume.level * 100) + "%") : ""
    property string seen
    property bool recent: false
    property int holdTime: 1800
    onReadingChanged: {
        if (reading !== "" && seen !== "") {
            recent = true;
            hold.restart();
        }
        seen = reading;
    }
    Component.onCompleted: seen = reading

    // Full size, scaled with the group while it steps back; the arc is not
    // redrawn for that. This is its own size, but a loader that fills the
    // scene resizes it: every place on the ring is measured from its middle,
    // never from its edge, which is what lines up with the group.
    readonly property real radius: centre.sizes.ring
    width: (radius + band + 2) * 2
    height: width
    x: centre.group.x - width / 2
    y: centre.group.y - height / 2
    scale: centre.group.scale
    opacity: centre.presence * (volume.ready ? 1 : 0.35)

    // A press lands where the pointer is, whatever the level was: the way
    // round the top is only kept while the pointer is held, from where it
    // last was (not from the level, which lags and may be capped)
    function press(x, y) {
        held = NaN;
        drag(x, y);
    }
    function drag(x, y) {
        held = Master.fromPointer(width / 2, height / 2, x, y, held);
        volume.set(held);
    }

    LevelArc {
        anchors.centerIn: parent
        radius: ring.radius
        lineWidth: ring.lineWidth
        level: ring.volume.level
        trackColor: ring.night.ink(0.14)
        levelColor: ring.volume.muted ? ring.night.ink(0.4) : ring.night.primary
        thumbSize: ring.thumbSize
        thumbColor: ring.night.ink(ring.volume.muted ? 0.5 : 0.95)
    }

    MouseArea {
        id: grab
        anchors.fill: parent
        enabled: ring.volume.ready
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        containmentMask: QtObject {
            function contains(point: point): bool {
                return Math.abs(Math.hypot(point.x - ring.width / 2, point.y - ring.height / 2) - ring.radius) <= ring.band;
            }
        }
        onPressed: m => ring.press(m.x, m.y)
        onPositionChanged: m => {
            if (pressed)
                ring.drag(m.x, m.y);
        }

        NotchWheel {
            onTurned: notches => {
                ring.volume.step(notches > 0 ? 1 : -1);
            }
        }
    }

    // Where the arc starts: the speaker, which follows the level and mutes
    // the group. Above the ring's grab, so a press on it is not a drag to zero.
    Rectangle {
        id: chip
        objectName: "speaker"
        width: ring.chipSize
        height: width
        radius: width / 2
        x: (ring.width - width) / 2
        y: ring.height / 2 - ring.radius - height / 2
        color: ring.night.smoke(0.9)
        border.width: 1
        border.color: ring.night.ink(0.14)

        DankIcon {
            anchors.centerIn: parent
            name: ring.glyph
            size: ring.iconSize
            color: ring.volume.muted ? ring.night.ink(0.5) : ring.night.primary
        }

        MouseArea {
            anchors.fill: parent
            enabled: ring.volume.ready
            cursorShape: Qt.PointingHandCursor
            onClicked: ring.volume.toggleMute()
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: chip.y - height
        visible: ring.volume.ready && (grab.containsMouse || grab.pressed || ring.recent)
        text: ring.reading
        color: ring.night.ink(0.9)
        font.pixelSize: Math.max(9, Math.round(ring.centre.scene.coreSize * 0.2))
        font.weight: Font.Medium
        font.features: {
            "tnum": 1
        }
    }

    // Nothing runs at rest: the timer starts with a change and stops itself
    Timer {
        id: hold
        interval: ring.holdTime
        onTriggered: ring.recent = false
    }
}
