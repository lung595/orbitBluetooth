import QtQuick
import qs.Widgets
import "../volume"
import "Radar.js" as Radar

// The volume radar, drawn: a veil over the sky, the hero's big dial in the middle
// with its name and its actions under it, and the other levels as small dials
// around it, each a tap from being the hero. What it shows and does is the
// state's (OrbitRadar); it only places the dials and passes the gestures on.
// Made only while the radar is open, so nothing here exists at rest.
Item {
    id: view

    required property var radar
    readonly property var night: radar.scene.night

    readonly property real side: Math.max(160, Math.min(width, height) * 0.92)
    readonly property var places: Radar.layout(radar.look, radar.ids.length - 1, side)
    // The hero, its name and the actions under it, and the satellites above it
    // are centred as one block
    readonly property real above: Math.max(places.hero.r, ...places.satellites.map(s => s.r - s.y))
    readonly property real below: places.hero.r + 72
    readonly property real cx: width / 2
    readonly property real cy: (height + above - below) / 2

    // Where a dial sits; a dial whose output just left has none left to take
    function slotOf(id) {
        const slot = id === radar.heroId ? places.hero : places.satellites[Radar.around(radar.ids, radar.heroId).indexOf(id)];
        return slot ?? {
            "x": 0,
            "y": 0,
            "r": 0
        };
    }

    // What a dial shows: its name, picture, level and color
    function infoOf(id) {
        const volume = radar.volume;
        if (id === "group")
            return {
                "name": "Group",
                "icon": "speaker_group",
                "level": volume.level,
                "muted": volume.muted,
                "ready": volume.ready,
                "color": palette.pc
            };
        const level = volume.ownLevel(id);
        const node = volume.ownNode(id);
        return {
            "name": radar.nameOf(id),
            "glyph": radar.glyphFor(id),
            "level": Math.max(0, level),
            "muted": !!node && node.audio.muted,
            "ready": level >= 0,
            "color": palette.colors[Math.max(0, radar.members.indexOf(id))]
        };
    }

    MemberPalette {
        id: palette
        count: view.radar.members.length
        bases: [view.night.primary, view.night.secondary, view.night.tertiary]
    }

    // A tap beside the dials closes it, as Escape does
    Rectangle {
        anchors.fill: parent
        color: view.night.smoke(0.8)
        MouseArea {
            anchors.fill: parent
            onClicked: view.radar.close()
        }
    }

    Repeater {
        model: view.radar.ids
        delegate: RadarDial {
            id: dial
            required property string modelData
            readonly property var slot: view.slotOf(modelData)

            info: view.infoOf(modelData)
            night: view.night
            hero: modelData === view.radar.heroId
            radius: slot.r
            x: view.cx + slot.x - slot.r
            y: view.cy + slot.y - slot.r
            onMoved: level => view.radar.setLevel(modelData, level)
            onStepped: dir => view.radar.step(modelData, dir)
            onMuteClicked: view.radar.toggleMute(modelData)
            onPicked: view.radar.show(modelData)
        }
    }

    RadarChips {
        width: Math.min(view.width - 32, 460)
        x: view.cx - width / 2
        y: view.cy + view.places.hero.r + 40
        night: view.night
        model: Radar.chips(view.radar.kindOf(view.radar.heroId))
        onChosen: id => view.radar.choose(id)
    }

    // Always a way out that can be seen, besides Escape
    Rectangle {
        x: view.width - width - 12
        y: 12
        width: 30
        height: width
        radius: width / 2
        color: closeArea.containsMouse ? view.night.ink(0.2) : view.night.ink(0.1)
        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: 17
            color: view.night.ink(0.9)
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.radar.close()
        }
    }
}
