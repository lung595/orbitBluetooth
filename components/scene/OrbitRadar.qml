import QtQuick
import qs.Common
import "../centre/MemberGlyph.js" as MemberGlyph
import "../common/Guide.js" as Guide
import "../radar/Radar.js" as Radar
import "../together/Member.js" as Member

// The volume radar of a listening group: opened from the icons of the group or
// from one of its members, it shows one level big (the hero: the group's, or the
// member's that was clicked) and the others small around it, all within reach.
// This is its state and what its gestures and actions do; RadarView draws it.
// Nothing exists while it is closed (the world's Loader), and a level is only read and
// written here, on the hero's or a satellite's gesture.
Item {
    id: orbit

    required property var scene
    readonly property var centre: scene.centre
    readonly property var volume: centre.volume
    readonly property var route: volume.route

    // The radar is on screen; `hero` is the dial asked to be big ("" is the
    // group's, an address a member's)
    property bool open: false
    property string hero: ""
    // The look it has: the setting's, hero + satellites for now
    property string look: Radar.styleOf("")

    // The outputs sharing the sound, the source first, and every dial: the group's, then each of them
    readonly property var members: centre.grouped ? [centre.source].concat(centre.copies) : []
    readonly property var ids: ["group"].concat(members)
    readonly property string heroId: Radar.heroOf(ids, hero === "" ? "group" : hero)

    function kindOf(id) {
        return id === "group" ? "group" : Member.isWired(id) ? "wired" : "bluetooth";
    }
    function nameOf(id) {
        return scene.together.nameOf(id);
    }
    function glyphFor(id) {
        return MemberGlyph.glyphOf(id, volume.session ? volume.session.memberNode(id) : null, scene.deviceMap[id], scene.prefs.glyphOverrides);
    }
    // The body drawn for an output (a device's, or a wired member's), null when none
    function bodyOf(id) {
        return scene.world.bodyList().find(b => b.address === id) ?? null;
    }

    // The Bluetooth hero's planet flies to the card like a device's (the scene's
    // focusBody); a group or a wired output has no planet of its own to fly, and
    // the card carries its picture (RadarGlyph)
    readonly property var flier: open && kindOf(heroId) === "bluetooth" ? bodyOf(heroId) : null
    onFlierChanged: scene.focusBody = flier

    function show(id) {
        if (!centre.grouped)
            return;
        // A detail card of another device gives way
        if (!open)
            scene.clearFocus();
        hero = members.indexOf(id) >= 0 ? id : "";
        open = true;
        scene.wake();
        scene.forceActiveFocus();
    }
    // The hero stays as it was, so the card does not change under its own fade
    function close() {
        open = false;
        scene.wake();
    }

    // The group ended, or the popout closed: the radar never stays on what is gone
    Connections {
        target: orbit.centre
        function onGroupedChanged() {
            if (!orbit.centre.grouped)
                orbit.close();
        }
    }
    Connections {
        target: orbit.scene
        function onActiveChanged() {
            if (!orbit.scene.active)
                orbit.close();
        }
    }

    // --- Gestures on a dial: the group's level, or a member's own -----------------
    // A member whose device keeps no level of its own says why, never silence
    function _noLevel(id) {
        if (!scene.note || scene.note.anchor !== "the-volume-at-the-center")
            scene.explain(Guide.copyLevelNote(nameOf(id)));
    }
    function setLevel(id, value) {
        if (id === "group") {
            volume.set(value);
            return;
        }
        const node = volume.ownNode(id);
        if (!node) {
            _noLevel(id);
            return;
        }
        const to = Math.round(Math.max(0, Math.min(1, value)) * 100) / 100;
        if (Math.abs(to - node.audio.volume) < 0.005)
            return;
        SessionData.suppressOSDTemporarily();
        route.writeLevel(node, to);
    }
    function step(id, dir) {
        if (id === "group") {
            volume.step(dir);
            return;
        }
        const node = volume.ownNode(id);
        if (!node) {
            _noLevel(id);
            return;
        }
        SessionData.suppressOSDTemporarily();
        route.stepNode(node, dir);
    }
    function toggleMute(id) {
        if (id === "group") {
            volume.toggleMute();
            return;
        }
        const node = volume.ownNode(id);
        if (!node) {
            _noLevel(id);
            return;
        }
        SessionData.suppressOSDTemporarily();
        route.writeMuted(node, !node.audio.muted);
    }

    // --- The hero's actions (Radar.chips) -----------------------------------------
    // A member left: back to the group's level, or closed when none is left to tune
    function _left() {
        hero = "";
        if (!centre.grouped)
            close();
    }
    function choose(action) {
        const id = heroId;
        const body = bodyOf(id === "group" ? centre.source : id);
        switch (action) {
        case "add":
            close();
            scene.openGroupChooser(body, Qt.point(scene.width / 2, scene.height / 2));
            break;
        case "stop":
            close();
            scene.together.stop();
            break;
        case "leave":
            scene.together.leave(id);
            _left();
            break;
        case "disconnect":
            // A wired output cannot be disconnected: it leaves the group and stays plugged in
            if (Member.isWired(id))
                scene.together.leave(id);
            else
                scene.startDisconnect(body);
            _left();
            break;
        case "hide":
            close();
            scene.hideBody(body);
            break;
        case "details":
            close();
            scene.focusOn(body, true);
            break;
        }
    }

    // The card itself (RadarView) is drawn in the world, in the detail card's rise
    // (CardSlide), so the planet that flies to it can sit above it
    // The sky's guided note lies under the veil: it is shown again over it, so a
    // dial that cannot do what was asked never answers with silence (value 10)
    Loader {
        anchors.fill: parent
        active: orbit.open
        sourceComponent: OrbitNote {
            scene: orbit.scene
        }
    }
}
