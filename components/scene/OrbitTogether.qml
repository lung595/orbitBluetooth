import QtQuick
import "../common/Guide.js" as Guide
import "../device/DeviceCatalog.js" as Catalog

// Listen together in the scene (D254, D277): what dropping one connected
// audio device onto another says and does, and how a device leaves or the
// session ends. The session itself is the daemon's (TogetherSession, reached
// through the AudioRoute); this only asks it and says the answer under the
// orbit, never in silence (value 10).
Item {
    id: together
    required property var scene

    readonly property var session: scene.audioRoute ? scene.audioRoute.together : null

    function _name(address) {
        return Catalog.deviceName(scene.deviceMap[address]) || (session ? session.nameOf(address) : "");
    }

    // Worth a hint: both are connected and one of them plays sound
    function relevant(b, o) {
        return !!session && !!b && !!o && session.relevant(b.address, o.address);
    }
    // The note for this drop, null when it can be done
    function _note(b, o) {
        const r = session ? session.dropCheck(b.address, o.address) : null;
        return r ? Guide.togetherNote(r.why, _name(r.address)) : null;
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

    // A member disconnected or the session ended by itself: the user is told
    // while the orbit is open. What the user asked for needs no note.
    Connections {
        target: together.session
        function onEnded(why, address) {
            if (why !== "ended" && together.scene.active)
                together.scene.explain(Guide.togetherNote(why, together._name(address)));
        }
        function onMemberLeft(address) {
            if (together.scene.active)
                together.scene.explain(Guide.togetherNote("member-out", together._name(address)));
        }
    }
}
