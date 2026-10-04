import QtQuick
import qs.Common
import qs.Widgets
import "MasterVolume.js" as Master
import "../volume"

// The ring around the source at the centre: the general volume of the group
// (D284). It fills clockwise from the top; drag along it or turn the wheel
// over it to move every member's level together, keeping the gaps between
// them. A wheel over the planet itself does the same (BodyWheel).
Item {
    id: ring

    required property var centre
    readonly property var volume: centre.volume
    readonly property var night: centre.scene.night
    // Where the pointer grabs the ring: a band around it, easier to hit than
    // the thin line itself
    readonly property real band: 11

    // Full size, scaled with the group while it steps back; the arc is not
    // redrawn for that
    readonly property real radius: centre.sizes.ring
    width: (radius + band + 2) * 2
    height: width
    x: centre.group.x - width / 2
    y: centre.group.y - height / 2
    scale: centre.group.scale
    opacity: centre.presence * (volume.ready ? 1 : 0.35)

    LevelArc {
        anchors.centerIn: parent
        radius: ring.radius
        lineWidth: 3
        level: ring.volume.level
        trackColor: ring.night.ink(0.14)
        levelColor: ring.volume.muted ? ring.night.ink(0.4) : ring.night.primary
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
        onPressed: m => move(m)
        onPositionChanged: m => {
            if (pressed)
                move(m);
        }
        function move(m) {
            ring.volume.set(Master.fromPointer(ring.width / 2, ring.height / 2, m.x, m.y, ring.volume.level));
        }

        NotchWheel {
            onTurned: notches => {
                ring.volume.step(notches > 0 ? 1 : -1);
            }
        }
    }

    // The level, while the pointer is on the ring
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: ring.band - height
        visible: grab.containsMouse || grab.pressed
        text: Math.round(ring.volume.level * 100) + "%"
        color: ring.night.ink(0.9)
        font.pixelSize: Math.max(9, Math.round(ring.centre.scene.coreSize * 0.2))
        font.weight: Font.Medium
        font.features: {
            "tnum": 1
        }
    }
}
