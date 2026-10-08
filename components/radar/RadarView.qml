import QtQuick
import qs.Common
import "../card"
import "../volume"
import "Radar.js" as Radar
import "RadarMotion.js" as Motion

// The volume radar, drawn: the detail card's own card (RadarCard, in the same rise,
// see CardSlide), the hero's big dial in the middle with its actions under it (its
// name is the card's header), and the other levels as small dials around it, each a
// tap from being the hero. What it shows and does is the state's (OrbitRadar); this
// places the dials, passes the gestures on and owns the motion: one clock that runs
// only while something moves (the entrance, a hero swap, a level gliding, the mute
// ring) and never with Reduce motion.
// Made only while the radar is open, so nothing here exists at rest.
Item {
    id: view

    required property var radar
    readonly property var night: radar.scene.night
    readonly property bool motion: radar.scene.motion
    readonly property PaperColors paper: PaperColors {}
    readonly property alias clock: clock

    readonly property real margin: 12
    // The card's header sits over the dials, and the dials keep a margin under them
    readonly property real headerHeight: frame.headerHeight
    // The height this radar asks of its card (RadarView does not depend on the
    // scene's height: the glyph's overhang is the one at full size, as FocusLayout's)
    readonly property real wantedHeight: radar.scene.focusFullOverlap + frame.titleHeight + Theme.spacingS + Radar.blockHeight(radar.look, radar.ids.length - 1, width - margin * 2) + margin
    readonly property real room: height - headerHeight - margin
    readonly property real side: Radar.sideFor(radar.look, radar.ids.length - 1, width - margin * 2, room)
    readonly property var places: Radar.layout(radar.look, radar.ids.length - 1, side)
    // The hero, the small dials above it and the actions under it are centred as one
    // block, under the header
    readonly property var extent: Radar.extent(radar.look, radar.ids.length - 1, side)
    readonly property real cx: width / 2
    readonly property real cy: headerHeight + (room - extent.above - extent.below) / 2 + extent.above

    // --- What moves, and how far it has come ---------------------------------------
    // Seconds since the radar opened, up to the end of the entrance
    property real entranceT: 0
    readonly property real entranceEnd: Motion.ENTRANCE + Motion.STAGGER * (radar.ids.length - 1)
    readonly property bool entering: motion && entranceT < entranceEnd
    readonly property real cardIn: motion ? Motion.phase(entranceT, 0, 0.22) : 1
    // Where every dial ends up, where each was when the last change began, and
    // how far (seconds) the glide between them has gone
    property var targets: ({})
    property var fromSlots: ({})
    property real morphT: Motion.MORPH
    readonly property bool morphing: morphT < Motion.MORPH
    // The level each dial draws, gliding toward the real one
    property var shown: ({})
    readonly property bool levelsMoving: radar.ids.some(id => Math.abs(shownOf(id) - infoOf(id).level) > Motion.SNAP)
    // The mute ring: whose, and how far (seconds)
    property string rippleId: ""
    property real rippleT: Motion.RIPPLE
    readonly property bool rippling: rippleT < Motion.RIPPLE

    RadarClock {
        id: clock
        motion: view.motion
        busy: view.entering || view.morphing || view.levelsMoving || view.rippling
        onTick: dt => view.advance(dt)
    }

    // One step of the clock
    function advance(dt) {
        if (entering)
            entranceT += dt;
        if (morphing)
            morphT = Math.min(Motion.MORPH, morphT + dt);
        if (rippling)
            rippleT = Math.min(Motion.RIPPLE, rippleT + dt);
        if (levelsMoving) {
            const next = {};
            for (const id of radar.ids)
                next[id] = Motion.follow(shownOf(id), infoOf(id).level, dt, Motion.GLIDE);
            shown = next;
        }
    }
    function shownOf(id) {
        return shown[id] ?? 0;
    }
    // The level a dial draws: the glide's, or the real one with Reduce motion
    function levelOf(id) {
        return motion ? shownOf(id) : infoOf(id).level;
    }
    // How far a dial's entrance has come: the hero first, the small ones one after the other
    function popOf(id) {
        if (!motion)
            return 1;
        const i = Radar.around(radar.ids, radar.heroId).indexOf(id);
        return Motion.phase(entranceT, i < 0 ? 0.04 : 0.12 + Motion.STAGGER * i, 0.25);
    }
    function mute(id) {
        if (motion) {
            rippleId = id;
            rippleT = 0;
        }
        radar.toggleMute(id);
    }

    // --- Where the dials are ------------------------------------------------------------
    // Where each dial ends up, for the hero asked for and the dials there are now
    function layoutNow() {
        const spots = Radar.layout(radar.look, radar.ids.length - 1, side);
        const out = {};
        out[radar.heroId] = spots.hero;
        Radar.around(radar.ids, radar.heroId).forEach((id, i) => {
            out[id] = spots.satellites[i];
        });
        return out;
    }
    // Where a dial is now: on its way from where it was to where it ends up. A dial
    // with nowhere to go (its output just left) takes no room
    function slotOf(id) {
        const to = targets[id];
        if (!to)
            return {
                "x": 0,
                "y": 0,
                "r": 0
            };
        const from = fromSlots[id];
        return from && morphing ? Motion.slotMix(from, to, Motion.phase(morphT, 0, Motion.MORPH)) : to;
    }
    // The hero or the dials changed: every dial glides from where it is drawn now
    function retarget() {
        const was = {};
        for (const id of Object.keys(targets))
            was[id] = slotOf(id);
        fromSlots = was;
        targets = layoutNow();
        morphT = motion ? 0 : Motion.MORPH;
    }
    onSideChanged: {
        targets = layoutNow();
        fromSlots = {};
    }
    Component.onCompleted: targets = layoutNow()
    Connections {
        target: view.radar
        function onHeroIdChanged() {
            view.retarget();
        }
        function onIdsChanged() {
            view.retarget();
        }
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

    RadarCard {
        id: frame
        anchors.fill: parent
        scene: view.radar.scene
        paper: view.paper
        title: view.infoOf(view.radar.heroId).name
        subtitle: Radar.subtitle(view.radar.kindOf(view.radar.heroId), view.radar.members.length)
        heroInfo: view.infoOf(view.radar.heroId)
        // A Bluetooth member's planet flies to the card (the scene's focusBody); the group and a
        // wired output have none, so the card carries their picture
        carried: view.radar.kindOf(view.radar.heroId) !== "bluetooth"
        round: view.radar.kindOf(view.radar.heroId) === "group"
        heroKey: view.radar.heroId
        canGoBack: view.radar.heroId !== "group"
        onBack: view.radar.show("")
        onClosed: view.radar.close()
    }

    // The night sky seen through the card's glass, under the dials
    RadarSky {
        anchors.fill: parent
        opacity: view.cardIn
        paper: view.paper
        colors: palette.colors
        fallback: view.night.tertiary
        places: view.places
        cx: view.cx
        cy: view.cy
        side: view.side
        actionsY: chips.y
        headerHeight: view.headerHeight
    }

    Repeater {
        model: view.radar.ids
        delegate: RadarDial {
            id: dial
            required property string modelData
            readonly property var slot: view.slotOf(modelData)

            info: view.infoOf(modelData)
            paper: view.paper
            hero: modelData === view.radar.heroId
            level: view.levelOf(modelData)
            pop: view.popOf(modelData)
            ripple: modelData === view.rippleId ? Motion.phase(view.rippleT, 0, Motion.RIPPLE) : 1
            // The small dials and their names stay above the big one's ring
            z: hero ? 0 : 1
            radius: slot.r
            x: view.cx + slot.x - slot.r
            y: view.cy + slot.y - slot.r
            onMoved: level => view.radar.setLevel(modelData, level)
            onStepped: dir => view.radar.step(modelData, dir)
            onMuteClicked: view.mute(modelData)
            onPicked: view.radar.show(modelData)
        }
    }

    RadarChips {
        id: chips
        x: view.cx - width / 2
        y: view.cy + view.places.hero.r + Radar.UNDER
        paper: view.paper
        opacity: view.cardIn
        rows: Radar.chipRows(view.radar.kindOf(view.radar.heroId))
        onChosen: id => view.radar.choose(id)
    }
}
