import QtQuick
import "../common/Guide.js" as Guide
import "../device/DeviceCatalog.js" as Catalog
import "../together/Choice.js" as Choice

// Listen together in the scene (D254, D277, D298): what dropping one connected
// audio device onto another says and does, how a group is made from the
// menu's chooser, and how a device leaves or the session ends. The session
// itself is the daemon's (TogetherSession, reached through the AudioRoute);
// this only asks it and says the answer under the orbit, never in silence
// (value 10).
Item {
    id: together
    required property var scene

    readonly property var session: scene.audioRoute ? scene.audioRoute.together : null

    // The name the user sees, for a note and for the group's label
    function nameOf(address) {
        return Catalog.deviceName(scene.deviceMap[address]) || (session ? session.nameOf(address) : "");
    }

    // Worth a hint: both are connected and one of them plays sound, or `b` is
    // not connected yet and `o` listens (the hint says to connect it first)
    function relevant(b, o) {
        return !!session && !!b && !!o && (session.relevant(b.address, o.address) || (!b.connected && session.isMember(o.address)));
    }
    // The note for this drop, null when it can be done
    function _note(b, o) {
        const r = session ? session.dropCheck(b.address, o.address) : null;
        return r ? Guide.togetherNote(r.why, nameOf(r.address), r.address) : null;
    }
    // Under the orbit while the dragged device is over another
    function hint(b, o) {
        const n = _note(b, o);
        return n ? n.title : "Release to listen together";
    }
    // Whether dropping here would do it (the pop and the snap say so)
    function ready(b, o) {
        return relevant(b, o) && !_note(b, o);
    }

    // The bodies the carried device could join right now (where the scene
    // shows the invitation); none for a device that is not connected, as
    // dropping it would only say to connect it first
    function candidates(b) {
        return b ? scene.world.bodyList().filter(o => o !== b && !o.leaving && ready(b, o)) : [];
    }

    // The drop: starts a session or adds a device to it, or says why not
    function drop(b, o) {
        const n = _note(b, o);
        if (n) {
            scene.explain(n);
            return;
        }
        session.join(b.address, o.address);
        scene.sounds.play("connect");
    }

    function isMember(address) {
        return !!session && session.isMember(address);
    }
    function count() {
        return session ? session.members.length : 0;
    }
    // One device leaves; with fewer than two left the session ends
    function leave(address) {
        if (session && !session.remove(address))
            scene.sounds.play("disconnect");
    }
    function stop() {
        if (session && session.end("ended", ""))
            scene.sounds.play("disconnect");
    }

    // --- A group made from the menu (GroupChooser) -------------------------------
    // The members of the session, [] when nothing is shared
    function members() {
        return session ? session.members : [];
    }
    // Why `who` could not take part in any group, null when it can (what the
    // chooser lists by); with no session to ask, nothing can
    function memberCheck(who) {
        return session ? session.memberCheck(who) : {
            "why": "not-connected",
            "address": who
        };
    }
    // Whether the menu offers a group on `b`: it is connected and plays sound, or
    // it only waits for its call profile to end (the chooser then says so)
    function canGroup(b) {
        if (!b)
            return false;
        const r = memberCheck(b.address);
        return !r || r.why === "in-call";
    }
    // Says under the orbit why `who` cannot take part, never in silence
    function refuse(why, who) {
        scene.explain(Guide.togetherNote(why, nameOf(who)));
    }
    // What the chooser's button does: a new group with what is ticked, or the
    // newcomers added to the one there is; else it says why not
    function groupFrom(chosen) {
        if (!session)
            return;
        const p = Choice.outcome(session.members, chosen);
        const r = p.why ? {
            "why": p.why,
            "address": ""
        } : p.mode === "add" ? session.add(p.list) : session.start(p.list);
        if (r)
            refuse(r.why, r.address);
        else
            scene.sounds.play("connect");
    }

    // A member disconnected or the session ended by itself: the user is told
    // while the orbit is open. What the user asked for needs no note.
    Connections {
        target: together.session
        function onEnded(why, address) {
            if (why !== "ended" && together.scene.active)
                together.scene.explain(Guide.togetherNote(why, together.nameOf(address), address));
        }
        function onMemberLeft(address) {
            if (together.scene.active)
                together.scene.explain(Guide.togetherNote("member-out", together.nameOf(address), address));
        }
    }
}
