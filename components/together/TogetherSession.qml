pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell.Services.Pipewire
import "Delay.js" as Delay
import "Member.js" as Member
import "Together.js" as Together
import "Wired.js" as Wired

// Listen together (D254, D277, D298): two to four outputs, Bluetooth or wired,
// play the same sound. This is the session: who the members are, where the
// sound is taken from, and the copies that carry it to the other members
// (TogetherLink), which exist only while the session does. Event-driven:
// nothing here polls, and with no session nothing is loaded.
// A Bluetooth member stays a member while BlueZ says it is connected, even
// when its output goes quiet or a multipoint headset hands its link to the
// phone: its copy is simply stopped while the output is away and started again
// when it returns, and no stream is ever held towards it (D279). A wired
// member is there while its output node is. The session ends when fewer than
// two members remain, on the user's request, or if a copy dies. Nothing here
// touches a device's Bluetooth link.
Item {
    id: session

    // The daemon's AudioRoute: which Bluetooth devices there are and their
    // outputs, and the wired outputs and their delay filters
    required property var route
    // The user's nudge on the automatic wait of the wired outputs (ms)
    property int fineDelayMs: 0

    // The members (a Bluetooth address with colons, or a wired output's node
    // name: Member.js) in the order they joined, which is also the order of the
    // arcs on screen; [] while nothing is shared
    property var members: []
    // Extra delay of a member's copy in ms ({ member: ms }), for this session
    // only: nothing is saved
    property var delays: ({})
    readonly property bool active: members.length >= 2

    // The session is over: why ("ended" when the user asked, "member-left" when
    // a member disconnected, "link-stopped" when a copy died) and the address
    // concerned, "" if none
    signal ended(string why, string address)
    // A member disconnected and the others go on
    signal memberLeft(string address)

    // The name the user sees, for a note: a device's name, or a wired
    // output's description (cleaned, and never written to a log)
    function nameOf(who) {
        if (Member.isWired(who)) {
            const n = route.wiredSink(who);
            return n ? Wired.labelOf(n.nickname || n.description) : "";
        }
        const d = route.known(who);
        return d ? d.name : "";
    }
    function isMember(who) {
        return members.indexOf(who) >= 0;
    }

    // --- What Together.js asks about an output ---------------------------------------
    // A wired output is there while its node is (no profile, no filter of the
    // PC level); `pc` is then the delay filter Orbit runs in front of it, once
    // it exists
    function _facts(who) {
        if (Member.isWired(who)) {
            const n = route.wiredSink(who);
            return n ? {
                "connected": true,
                "sink": n.name,
                "profile": ""
            } : null;
        }
        const d = route.known(who);
        return d ? {
            "connected": d.connected,
            "sink": d.sink ? d.sink.name : "",
            "profile": _profile(d)
        } : null;
    }
    function _sound(who) {
        if (Member.isWired(who)) {
            const n = route.wiredSink(who);
            const f = route.wiredFilter(who);
            return n ? {
                "sink": n.name,
                "pc": f ? f.name : "",
                "profile": ""
            } : null;
        }
        const d = route.known(who);
        return d ? {
            "sink": d.sink ? d.sink.name : "",
            "pc": d.pc ? d.pc.name : "",
            "profile": _profile(d)
        } : null;
    }
    function _profile(d) {
        return d.sink && d.sink.properties ? d.sink.properties["api.bluez5.profile"] : "";
    }
    function _codec(d) {
        return d.sink && d.sink.properties ? d.sink.properties["api.bluez5.codec"] || "" : "";
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
        _begin(list.map(Together.member));
        return null;
    }
    // Adds devices to the session
    function add(list) {
        const r = joinCheck(list);
        if (r)
            return r;
        _admit(list.map(Together.member));
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
        if (!isMember(Together.member(a)) && !isMember(Together.member(b)))
            return {
                "why": "outside",
                "address": Together.member(a)
            };
        const newcomers = Together.merge(members, a, b).slice(members.length);
        return newcomers.length ? joinCheck(newcomers) : {
            "why": "already",
            "address": Together.member(a)
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
            _begin([Together.member(a), Together.member(b)]);
        return null;
    }
    // A member leaves on the user's request; the session ends if fewer than
    // two remain
    function remove(address) {
        const a = Together.member(address);
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

    // A member's copy waits this long more, 0..1000 ms (a restart of that copy, no more)
    function setDelay(address, ms) {
        delays = Together.withDelay(delays, members, address, ms);
    }

    // --- Where the sound comes from ----------------------------------------------------
    // The output in use, if it is a member: it is the source. Otherwise the
    // first member that has an output. Read again when the default output changes.
    readonly property var plan: active ? Together.plan(members, _sound, Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.name : "") : null
    readonly property string source: plan ? plan.source : ""

    // --- How long each output waits (D298) -------------------------------------------------
    // What each member adds before it is heard, read from PipeWire's graph:
    // once when the session forms and again when a member's output, codec or
    // profile changes (MemberLatency, which exists only during a session)
    readonly property var latencies: latencyLoader.item ? latencyLoader.item.latencies : ({})
    readonly property var _sinks: {
        const out = {};
        for (const a of active ? members : []) {
            const f = _facts(a);
            if (f && f.sink)
                out[a] = f.sink;
        }
        return out;
    }
    // Text, so that it signals only when a figure may have changed
    readonly property string _signature: JSON.stringify((active ? members : []).map(a => {
        const d = Member.isWired(a) ? null : route.known(a);
        return [a, _sinks[a] || "", d ? _codec(d) : "", d ? _profile(d) : ""];
    }))
    Loader {
        id: latencyLoader
        active: session.active
        sourceComponent: MemberLatency {
            sinks: session._sinks
            signature: session._signature
        }
    }

    // The copies to run, kept while they do not change so that a level or a
    // name moving does not restart anything. A wired source waits in a filter
    // of its own (the first entry), the other wired members in their copies,
    // each with the user's own delay added.
    property var _copies: []
    function _replan() {
        let wanted = [];
        if (active) {
            const waits = Delay.waitsFor(plan, latencies, fineDelayMs);
            wanted = Together.commands(plan, Delay.total(waits.taps, delays), waits.source);
        }
        if (JSON.stringify(wanted) !== JSON.stringify(_copies))
            _copies = wanted;
    }
    onPlanChanged: _replan()
    onDelaysChanged: _replan()
    onActiveChanged: _replan()
    onLatenciesChanged: _replan()
    onFineDelayMsChanged: _replan()

    // --- Members that leave -------------------------------------------------------------
    // The members that are no longer there (BlueZ says a device is not
    // connected, a wired output's node is gone), as one text so that the
    // handler runs when the set changes, not each time a device updates
    readonly property string _gone: members.filter(a => {
        const f = _facts(a);
        return !f || !f.connected;
    }).join(",")
    // Leaving changes `members`, which `_gone` reads: it is done once this
    // update is over, not inside it
    on_GoneChanged: Qt.callLater(_leaveGone)
    function _leaveGone() {
        if (_gone)
            _leave(_gone.split(","), "member-left");
    }

    // --- The levels the face shows (D254) ---------------------------------------------------
    // A wired output's level is readable once PipeWire is asked for it (a
    // Bluetooth device's is, by its RouteDevice): only the members' outputs
    PwObjectTracker {
        objects: (session.active ? session.members : []).filter(a => Member.isWired(a)).map(a => session.route.wiredSink(a)).filter(n => !!n)
    }
    // A member's own level (the device's, else the one of its output; a wired
    // output has only its own)
    function memberNode(who) {
        if (Member.isWired(who))
            return route.wiredSink(who);
        const d = route.known(who);
        return d ? (route.deviceNode(d) || d.sink) : null;
    }
    // The level the face shows: this PC's level on the source (a wired
    // source's output level)
    readonly property var sharedNode: {
        if (Member.isWired(source))
            return route.wiredSink(source);
        const d = source ? route.known(source) : null;
        return d ? (route.pcNode(d) || d.sink) : null;
    }
    // The copy is taken from the source's PC-level filter, before its level,
    // so each member applies the level itself through its own filter and they
    // must all hold the same one: writing one writes them all
    // (Route.levelNodes). A source without that filter is copied after
    // its output level (it is the PC level there), so nothing is shared: each
    // member then plays that sound at its own level. So does a wired source,
    // whose copies are taken before its output level, and a wired member,
    // which has no filter of the PC level.
    readonly property var sharedNodes: {
        const d = active && source ? route.known(source) : null;
        if (!d || !d.pc)
            return [];
        return members.map(a => {
            const m = route.known(a);
            return m ? m.pc : null;
        }).filter(n => !!n && !!n.audio);
    }
    // Newcomers start at the level the others share, and unmuted as they are
    function _align(who) {
        const from = sharedNodes.length ? sharedNode : null;
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

    // A member's PC filter came up after it joined (it was away, or slower
    // than the others): it takes the shared level and mute like a newcomer.
    // The source's own filter coming up is the reference the others follow.
    function realign(address) {
        if (isMember(address))
            _align(address === source ? members : [address]);
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
