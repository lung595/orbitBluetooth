import QtQuick
import Quickshell.Services.Pipewire
import "../common/Guide.js" as Guide
import "../together"
import "../together/Ghost.js" as Ghost
import "../together/Habits.js" as Habits
import "../together/Member.js" as Member
import "Centre.js" as Centre
import "Perspective.js" as Perspective

// The group the scene proposes (D298, D299): the sound goes to a wired output and a
// Bluetooth device is connected, or the other way round. It is the group the user
// listens to most when that is all there, else a pair. A ghost planet, a
// group that does not exist yet, takes the slot on the host's ring where the
// real group would sit (Fedora's view, never the group's own). A click makes it
// real; a right click or the cross turns it down until the shell ends
// (TogetherSession.declined), and it is not proposed during a session. This is
// the state and what it answers (who would be in, where it sits, how present it
// is, what a click does); GhostGroup draws it. It owns no timer: OrbitPhysics
// calls advance() on its own step, so the fade rides the one loop that already
// stops when nobody looks. With Reduce motion it simply is there or is not.
Item {
    id: ghost

    required property var scene
    // OrbitCentre: whether a group has the centre, and where the host is
    required property var centre
    // The daemon's TogetherSession; null before the daemon is up
    required property var session

    readonly property var route: scene.audioRoute

    // --- Whether a group can be proposed at all -----------------------------------------
    // Someone looks at the scene, the group at the centre is allowed (the ghost is the
    // planet that group would be), nothing is shared yet, and no group is still on its
    // way back: the ghost lives in Fedora's view
    readonly property bool _open: scene.active && scene.prefs.togetherCentre && !!session && !session.active && !!route && !centre.grouped

    // --- What the proposal is made of ------------------------------------------------------
    // The member that is the output in use: the Bluetooth device the sound goes to, or the
    // wired output PipeWire's default is (by its node name); "" for anything else
    readonly property string _heard: {
        if (!_open)
            return "";
        const device = route.current;
        if (device)
            return device.address;
        const sink = Pipewire.defaultAudioSink;
        return sink ? Member.clean(sink.name) : "";
    }
    readonly property var _bluetooth: _open ? route.audioDevices().map(d => d.address) : []

    // What the ghost has learned of the user's groups (D299); nothing while learning is off
    readonly property var _habits: scene.prefs.learnHabits ? scene.prefs.togetherHabits : null
    // The wired outputs plugged in are read while the sound goes to Bluetooth, and otherwise
    // only if a learned group holds an output that is not already known: when the output in
    // use is the wired one, its name is all the pair needs
    WiredWatch {
        id: watch
        active: ghost._open && (!!ghost.route.current || Habits.reaches(ghost._habits, [ghost._heard].concat(ghost._bluetooth)))
    }
    // ...and again when something that could change the answer did (a cable plugged in
    // makes a node appear, the output in use changes): nothing is polled
    readonly property string _outputs: _open ? Ghost.signature(_heard, _bluetooth, Pipewire.nodes.values) : ""
    on_OutputsChanged: if (_open)
        watch.refresh()

    // The group to propose: { members, key }, or null: the group the user listens to most
    // when it is all there, else a pair. What the user hid is never in it, and the session's
    // own rules decide who can be in, so a click does what the ghost shows.
    readonly property var proposal: _open ? Ghost.proposal({
        "output": _heard,
        "bluetooth": _bluetooth,
        "wired": watch.outputs.map(o => o.sink),
        "hidden": scene.prefs.hiddenDevices,
        "habits": _habits,
        "day": Habits.dayOf(Date.now()),
        "declined": session.declined
    }, list => session.check(list)) : null
    readonly property string key: proposal ? proposal.key : ""
    // Proposed, and not turned down
    readonly property bool offered: key !== "" && !!session && !session.isDeclined(key)
    // The name under it, "XM6 + Scarlett": the output in use first
    readonly property string label: proposal ? Centre.label(proposal.members.map(a => scene.together.nameOf(a))) : ""

    // --- How present it is -----------------------------------------------------------------------
    property real presence: 0
    // The ghost is there: drawn, and its slot on the ring kept while it fades away
    readonly property bool shown: offered || presence > 0
    // Still on its way: the loop keeps going
    readonly property bool fading: presence !== (offered ? 1 : 0)

    function advance(dt) {
        const goal = offered ? 1 : 0;
        presence = scene.awake && scene.motion ? Centre.approach(presence, goal, dt, Centre.FADE) : goal;
    }
    onOfferedChanged: {
        // Nobody sees it: no fade
        if (!scene.awake)
            presence = offered ? 1 : 0;
        scene.wake();
    }
    // The view closes or the screen goes off with the ghost half faded: the loop
    // is not stepping any more, so it lands here, and what is not shown unloads
    readonly property bool _seen: scene.awake
    on_SeenChanged: if (!_seen)
        presence = offered ? 1 : 0
    Component.onCompleted: if (offered)
        scene.wake()

    // --- Where it sits (the physics step lays the ring out and hands the slot over) -----------
    property var _slot: ({
            "x": 0,
            "y": 0,
            "depth": 1
        })
    // The step has laid the ring out with it: before that it has no place to be drawn at
    property bool _placed: false
    readonly property bool placed: _placed
    function place(slot) {
        _slot = slot;
        _placed = true;
    }
    onShownChanged: if (!shown)
        _placed = false
    readonly property real px: _slot.x
    readonly property real py: _slot.y
    readonly property real depth: _slot.depth
    // As big as the group is on that slot (Centre.GROUP_SIZE of the host's core), and as dark
    // as a planet of the ring at that depth, by the law of the view the scene is in
    readonly property real baseDiameter: scene.coreSize * Centre.GROUP_SIZE
    readonly property real depthScale: Perspective.size(depth, centre.profile)
    readonly property real diameter: baseDiameter * depthScale
    readonly property real haze: Perspective.haze(depth, centre.profile)
    // Stacked as a connected device is: behind the host's core on the far side of the ring,
    // by height otherwise
    readonly property real stack: Centre.bodyZ({
        "role": "",
        "inSlot": true,
        "depth": depth,
        "py": py
    }, false, 0)

    // --- What the user does ------------------------------------------------------------------------------
    // A click: the group becomes real. If the session cannot (a device went away since it
    // was proposed) the user is told why, never left without an answer (value 10).
    function accept() {
        if (!offered)
            return;
        const refused = session.start(proposal.members);
        if (refused)
            scene.explain(Guide.togetherNote(refused.why, scene.together.nameOf(refused.address)));
        else
            scene.sounds.play("connect");
    }
    // A right click or the cross: not this group again until the shell ends
    function decline() {
        if (offered)
            session.decline(key);
    }
}
