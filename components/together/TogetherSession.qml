pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell.Services.Pipewire
import "Together.js" as Together

// Listen together (D254, D277): two to four Bluetooth outputs play the same
// sound. This is the session: who the members are, where the sound is taken
// from, and the copies that carry it to the other members (TogetherLink),
// which exist only while the session does. Event-driven: nothing here polls,
// and with no session nothing is loaded.
// A member stays a member while BlueZ says it is connected, even when its
// output goes quiet or a multipoint headset hands its link to the phone: its
// copy is simply stopped while the output is away and started again when it
// returns, and no stream is ever held towards it (D279). The session ends
// when fewer than two members remain, on the user's request, or if a copy
// dies. Nothing here touches a device's Bluetooth link.
Item {
    id: session

    // The daemon's AudioRoute: which Bluetooth devices there are and their outputs
    required property var route

    // The members (addresses with colons) in the order they joined, which is
    // also the order of the arcs on screen; [] while nothing is shared
    property var members: []
    // Extra delay of a member's copy in ms ({ address: ms }), for this session
    // only: nothing is saved
    property var delays: ({})
    readonly property bool active: members.length >= 2

    // The session is over: why ("ended" when the user asked, "member-left" when
    // a member disconnected, "link-stopped" when a copy died) and the address
    // concerned, "" if none
    signal ended(string why, string address)
    // A member disconnected and the others go on
    signal memberLeft(string address)

    // The name the user sees, for a note
    function nameOf(address) {
        const d = route.known(address);
        return d ? d.name : "";
    }
    function isMember(address) {
        return members.indexOf(address) >= 0;
    }

    // --- What Together.js asks about a device ---------------------------------------
    function _facts(address) {
        const d = route.known(address);
        return d ? {
            "connected": d.connected,
            "sink": d.sink ? d.sink.name : "",
            "profile": _profile(d)
        } : null;
    }
    function _sound(address) {
        const d = route.known(address);
        return d ? {
            "sink": d.sink ? d.sink.name : "",
            "pc": d.pc ? d.pc.name : "",
            "profile": _profile(d)
        } : null;
    }
    function _profile(d) {
        return d.sink && d.sink.properties ? d.sink.properties["api.bluez5.profile"] : "";
    }

    // --- Who takes part ---------------------------------------------------------------
    // Each of these answers null when it could be done, or { why, address }
    function check(list) {
        return Together.refusal(list, _facts);
    }
    function joinCheck(list) {
        return active ? Together.joinRefusal(members, list, _facts) : {
            "why": "no-session",
            "address": ""
        };
    }
    // Both are connected and one of them plays sound: worth trying, and worth
    // saying why not when the other one cannot (the drag gesture)
    function relevant(a, b) {
        const x = _facts(a), y = _facts(b);
        return !!x && !!y && a !== b && x.connected && y.connected && (!!x.sink || !!y.sink);
    }

    // Starts a session with exactly these devices (replacing the current one,
    // whose copies that still fit keep running)
    function start(list) {
        const r = Together.refusal(list, _facts);
        if (r)
            return r;
        _begin(list.map(Together.address));
        return null;
    }
    // Adds devices to the session
    function add(list) {
        const r = joinCheck(list);
        if (r)
            return r;
        _admit(list.map(Together.address));
        return null;
    }
    function _begin(list) {
        members = list;
        delays = {};
        _align(list);
    }
    function _admit(newcomers) {
        members = members.concat(newcomers);
        _align(newcomers);
    }

    // The drop of `a` onto `b` in the orbit: why it cannot be done, or null
    function dropCheck(a, b) {
        if (!active)
            return check([a, b]);
        if (!isMember(Together.address(a)) && !isMember(Together.address(b)))
            return {
                "why": "outside",
                "address": Together.address(a)
            };
        const newcomers = Together.merge(members, a, b).slice(members.length);
        return newcomers.length ? joinCheck(newcomers) : {
            "why": "already",
            "address": Together.address(a)
        };
    }
    // The drop itself: starts a session, or adds the one of the two that is
    // not in it yet
    function join(a, b) {
        const r = dropCheck(a, b);
        if (r)
            return r;
        if (active)
            _admit(Together.merge(members, a, b).slice(members.length));
        else
            _begin([Together.address(a), Together.address(b)]);
        return null;
    }
    // A member leaves on the user's request; the session ends if fewer than
    // two remain
    function remove(address) {
        const a = Together.address(address);
        if (!isMember(a))
            return {
                "why": "not-member",
                "address": a
            };
        _leave([a], "ended");
        return null;
    }
    // Ends it, if there is one; why is told to `ended`
    function end(why, address) {
        if (!active)
            return false;
        members = [];
        delays = {};
        ended(why || "ended", address || "");
        return true;
    }
    function _leave(gone, why) {
        const next = members.filter(a => gone.indexOf(a) < 0);
        if (next.length < 2) {
            end(why, gone[0]);
            return;
        }
        members = next;
        delays = Together.prune(delays, next);
        if (why === "member-left")
            gone.forEach(a => memberLeft(a));
    }

    // A member's copy waits this long, 0..500 ms (a restart of that copy, no more)
    function setDelay(address, ms) {
        delays = Together.withDelay(delays, members, address, ms);
    }

    // --- Where the sound comes from ----------------------------------------------------
    // The output in use, if it is a member: it is the source. Otherwise the
    // first member that has an output. Read again when the default output changes.
    readonly property var plan: active ? Together.plan(members, _sound, Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.name : "") : null
    readonly property string source: plan ? plan.source : ""

    // The copies to run, kept while they do not change so that a level or a
    // name moving does not restart anything
    property var _copies: []
    function _replan() {
        const wanted = active ? Together.commands(plan, delays) : [];
        if (JSON.stringify(wanted) !== JSON.stringify(_copies))
            _copies = wanted;
    }
    onPlanChanged: _replan()
    onDelaysChanged: _replan()
    onActiveChanged: _replan()

    // --- Members that leave -------------------------------------------------------------
    // The members BlueZ no longer says are connected, as one text so that the
    // handler runs when the set changes, not each time a device updates
    readonly property string _gone: members.filter(a => {
        const d = route.known(a);
        return !d || !d.connected;
    }).join(",")
    on_GoneChanged: {
        if (_gone)
            _leave(_gone.split(","), "member-left");
    }

    // --- The levels the face shows (D254) ---------------------------------------------------
    // A member's own level (the device's, else the one of its output)
    function memberNode(address) {
        const d = route.known(address);
        return d ? (route.deviceNode(d) || d.sink) : null;
    }
    // The level this PC sends to the members, one per member: each member's
    // PC-level filter, and the source's own PC level when it has no filter.
    // The copy is taken before the PC level, so every member applies it
    // itself and they must all hold the same one: writing one writes them
    // all (AudioRoute.levelNodes).
    readonly property var sharedNodes: active ? members.map(a => {
        const d = route.known(a);
        return d ? (d.pc || (a === source ? route.pcNode(d) : null)) : null;
    }).filter(n => !!n && !!n.audio) : []
    // The one the face shows: the source's
    readonly property var sharedNode: {
        const d = source ? route.known(source) : null;
        return d ? (route.pcNode(d) || d.sink) : null;
    }
    // Newcomers start at the level the others share, and unmuted as they are
    function _align(who) {
        const from = sharedNode;
        if (!from || !from.audio)
            return;
        for (const a of who) {
            const d = route.known(a);
            if (d && d.pc && d.pc !== from && d.pc.audio) {
                d.pc.audio.volume = from.audio.volume;
                d.pc.audio.muted = from.audio.muted;
            }
        }
    }

    // Exists only during a session
    Loader {
        active: session.active
        sourceComponent: TogetherLink {
            copies: session._copies
            onLost: session.end("link-stopped", "")
        }
    }
}
