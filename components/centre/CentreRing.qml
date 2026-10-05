import QtQuick
import qs.Common
import qs.Widgets
import "Gauge.js" as Gauge
import "MasterVolume.js" as Master
import "../volume"

// The gauge around the source at the centre: the general volume of the group
// (D284). An open arc of 270 degrees with its gap at the bottom (where the
// members' row sits) fills clockwise from the speaker at its start, which says
// what it is and mutes the group when pressed; a round thumb sits at the end of
// the level, and the level is written out beside it while the pointer is on the
// gauge and for a moment after every change (D295). Drag along the band, click
// the track to jump there, or turn the wheel over it to move every member's
// level together, keeping the gaps between them. A wheel over the planet itself
// does the same (BodyWheel).
Item {
    id: ring

    required property var centre
    readonly property var volume: centre.volume
    readonly property var night: centre.scene.night
    // Where the pointer grabs the gauge: a band around its arc, easier to hit
    // than the thin line itself
    readonly property real band: 12
    readonly property real lineWidth: 5
    // The speaker at the arc's start and the chip behind it, which hides the
    // end of the track under it
    readonly property real iconSize: Math.max(10, Math.round(centre.scene.coreSize * 0.22))
    readonly property real chipSize: iconSize + 8
    readonly property string glyph: Master.icon(volume.level, volume.muted)
    // The thumb waits until the arc has left the speaker
    readonly property real thumbSize: Gauge.length(volume.level, radius) > chipSize ? lineWidth * 2.4 : 0
    // Where the pointer last read the gauge (0..1) while it is held; empty
    // (NaN) until the first reading of a press
    property real held: NaN

    // What the gauge says: the level, or that the group is muted; empty while
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

    // The source disc as it is drawn, and the one definition of where and how
    // big it is that the gauge follows: its body, which sits where its spring
    // has brought it and has grown to its role at the pace of the voyage, or
    // for a wired source (it has no body) the spot the group's rule gives it.
    // The group's own position and scale lead them while they move (the camera's
    // voyage, the sun carrying the group around the host), so the gauge would
    // be off the planet it is around.
    readonly property var body: centre.source !== "" ? centre.bodyOf(centre.source) : null
    readonly property var spot: centre.source !== "" && !body ? centre.spotOf(centre.source) : null
    readonly property real midX: body ? body.px : spot ? spot.x : centre.group.x
    readonly property real midY: body ? body.py : spot ? spot.y : centre.group.y
    readonly property real discSize: body ? body.diameter * body.baseScale : spot ? spot.size : centre.sizes.source * centre.group.scale

    // Full size, scaled with the disc as it grows or steps back; the arc is not
    // redrawn for that. This is its own size, but a loader that fills the
    // scene resizes it: every place on the gauge is measured from its middle,
    // never from its edge, which is what lines up with the disc.
    readonly property real radius: centre.sizes.ring
    width: (radius + band + 2) * 2
    height: width
    x: midX - width / 2
    y: midY - height / 2
    scale: discSize / centre.sizes.source
    opacity: centre.presence * (volume.ready ? 1 : 0.35)

    // A press lands where the pointer is, whatever the level was: the way
    // across the gap is only kept while the pointer is held, from where it
    // last was (not from the level, which lags and may be capped)
    function press(x, y) {
        held = NaN;
        drag(x, y);
    }
    function drag(x, y) {
        held = Master.fromPointer(width / 2, height / 2, x, y, held);
        volume.set(held);
    }

    LevelGauge {
        anchors.centerIn: parent
        radius: ring.radius
        lineWidth: ring.lineWidth
        level: ring.volume.level
        trackColor: ring.night.ink(0.14)
        startColor: ring.volume.muted ? ring.night.ink(0.4) : ring.night.primary
        endColor: ring.volume.muted ? ring.night.ink(0.4) : ring.night.tertiary
        glowColor: ring.volume.muted ? "transparent" : Theme.withAlpha(ring.night.tertiary, 0.5)
        tickColor: ring.night.ink(0.2)
        litColor: ring.night.ink(ring.volume.muted ? 0.3 : 0.65)
        thumbSize: ring.thumbSize
        thumbColor: ring.night.ink(ring.volume.muted ? 0.5 : 0.95)
        haloColor: ring.night.ink(0.22)
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
                return Gauge.hit(ring.width / 2, ring.height / 2, point.x, point.y, ring.radius, ring.band);
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
        readonly property var start: Gauge.pointAt(ring.width / 2, ring.height / 2, ring.radius, 0)
        width: ring.chipSize
        height: width
        radius: width / 2
        x: start.x - width / 2
        y: start.y - height / 2
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

    // The reading beside the thumb, pushed outward past the marks and far
    // enough that the chip clears the gauge whichever side the thumb is on
    Rectangle {
        id: tag
        readonly property real turn: Gauge.angleOf(ring.volume.level)
        readonly property real push: ring.lineWidth / 2 + 14 + Math.abs(Math.cos(turn)) * width / 2 + Math.abs(Math.sin(turn)) * height / 2
        visible: ring.volume.ready && (grab.containsMouse || grab.pressed || ring.recent)
        width: figure.implicitWidth + 14
        height: figure.implicitHeight + 6
        radius: height / 2
        x: ring.width / 2 + Math.cos(turn) * (ring.radius + push) - width / 2
        y: ring.height / 2 + Math.sin(turn) * (ring.radius + push) - height / 2
        color: ring.night.smoke(0.92)
        border.width: 1
        border.color: ring.night.ink(0.14)

        StyledText {
            id: figure
            anchors.centerIn: parent
            text: ring.reading
            color: ring.night.ink(0.9)
            font.pixelSize: Math.max(9, Math.round(ring.centre.scene.coreSize * 0.2))
            font.weight: Font.Medium
            font.features: {
                "tnum": 1
            }
        }
    }

    // Nothing runs at rest: the timer starts with a change and stops itself
    Timer {
        id: hold
        interval: ring.holdTime
        onTriggered: ring.recent = false
    }
}
