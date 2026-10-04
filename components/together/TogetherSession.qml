pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell.Services.Pipewire
import "Together.js" as Together

// Listen together (D254): two Bluetooth outputs play the same sound. This is
// the session: who the two members are, where the sound is taken from, and
// the one process that copies it (TogetherLink), which exists only while the
// session does. Event-driven: nothing here polls, and with no session
// nothing is loaded.
// A member stays a member while BlueZ says it is connected, even when its
// output goes quiet or a multipoint headset hands its link to the phone (the
// copy is passive and finds the output again by itself, D279). The session
// ends on a BlueZ disconnection, on the user's request, or if the copy dies.
Item {
    id: session

    // The daemon's AudioRoute: which Bluetooth devices there are and their outputs
    required property var route

    // The two members (addresses with colons), "" while nothing is shared
    property string first: ""
    property string second: ""
    // Extra delay of the copy in ms, for this session only: nothing is saved
    property int delayMs: 0
    readonly property bool active: first !== "" && second !== ""

    // The session ended: why ("member-left", "link-stopped", "ended") and the
    // address concerned (a member that left), "" if none
    signal ended(string why, string address)

    // The name the user sees, for a note
    function nameOf(address) {
        const d = route.known(address);
        return d ? d.name : "";
    }
    function isMember(address) {
        return active && (address === first || address === second);
    }
    function other(address) {
        return address === first ? second : address === second ? first : "";
    }

    // --- What Together.js asks about a device ---------------------------------------
    function _facts(address) {
        const d = route.known(address);
        if (!d)
            return null;
        return {
            "connected": d.connected,
            "sink": d.sink ? d.sink.name : "",
            "profile": d.sink && d.sink.properties ? d.sink.properties["api.bluez5.profile"] : ""
        };
    }
    function _sound(address) {
        const d = route.known(address);
        return d ? {
            "sink": d.sink ? d.sink.name : "",
            "pc": d.pc ? d.pc.name : ""
        } : null;
    }

    // Why these two cannot listen together ({ why, address }), or null
    function check(a, b) {
        return Together.refusal(a, b, _facts);
    }
    // Both are connected and one of them plays sound: worth trying, and
    // worth saying why not when the other one cannot (the drag gesture)
    function relevant(a, b) {
        const x = _facts(a), y = _facts(b);
        return !!x && !!y && a !== b && x.connected && y.connected && (!!x.sink || !!y.sink);
    }

    // Starts the session; returns null, or the refusal ({ why, address })
    function start(a, b) {
        const r = Together.refusal(a, b, _facts);
        if (r)
            return r;
        _argv = [];
        delayMs = 0;
        first = Together.address(a);
        second = Together.address(b);
        return null;
    }

    // Ends it, if there is one; why is told to `ended`
    function end(why, address) {
        if (!active)
            return false;
        first = "";
        second = "";
        _argv = [];
        delayMs = 0;
        ended(why || "ended", address || "");
        return true;
    }

    // The copy waits this long, 0..500 ms (a restart of the copy, no more)
    function setDelay(ms) {
        delayMs = Together.cleanDelay(ms);
    }

    // --- Where the sound comes from ----------------------------------------------------
    // The output in use, if it is a member: it is the source. Otherwise the
    // first member. Read again when the default output changes.
    readonly property var plan: active ? Together.plan(first, second, _sound, Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.name : "") : null
    readonly property string source: plan ? plan.source : ""

    // The copy's command; kept while a member's output is away, so the copy
    // is not restarted for nothing and picks the output up again itself
    property var _argv: []
    function _replan() {
        const a = active ? Together.args(plan, delayMs) : null;
        if (a && JSON.stringify(a) !== JSON.stringify(_argv))
            _argv = a;
    }
    onPlanChanged: _replan()
    onDelayMsChanged: _replan()
    onActiveChanged: _replan()

    // --- Members that leave -------------------------------------------------------------
    readonly property string _gone: {
        if (!active)
            return "";
        const a = route.known(first), b = route.known(second);
        return !a || !a.connected ? first : !b || !b.connected ? second : "";
    }
    on_GoneChanged: if (_gone)
        end("member-left", _gone)

    // --- The levels the face shows (D254) ---------------------------------------------------
    // Each member's own level (the device's, else the one of its output); the
    // level this PC sends, taken where the copy starts
    function memberNode(address) {
        const d = route.known(address);
        return d ? (route.deviceNode(d) || d.sink) : null;
    }
    readonly property var sharedNode: {
        const d = source ? route.known(source) : null;
        return d ? (route.pcNode(d) || d.sink) : null;
    }

    // Exists only during a session
    Loader {
        active: session.active
        sourceComponent: TogetherLink {
            command: session._argv
            onLost: session.end("link-stopped", "")
        }
    }
}
