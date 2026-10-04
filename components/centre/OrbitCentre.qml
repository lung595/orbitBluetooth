import QtQuick
import "Centre.js" as Centre

// The scene while a Listen together takes the centre (D281-D285): the source
// planet in the middle, its copies orbiting it, the host small and dimmed at
// the back. This is the state, and the answers the parts ask (where a member
// sits, how big it is, where the host is). It owns no timer: OrbitPhysics
// calls advance() on its own step, so the voyage, the orbit and the beams ride
// the one loop that already stops when nobody looks (and, with Reduce motion,
// never starts).
Item {
    id: centre

    required property var scene
    // The device bodies, to know where the source was when the group formed
    required property Repeater bodies
    // The daemon's TogetherSession; null before the daemon is up
    required property var session

    // The group takes the centre only when the setting allows it
    readonly property bool wanted: scene.prefs.togetherCentre && !!session && session.active

    // The group as it was last wanted, kept while the camera travels back
    property var members: []
    property string source: ""
    readonly property var copies: Centre.copiesOf(members, source)
    // How far the camera has followed the source to the centre, and how far
    // the group has stepped back to give the centre to the host (a click on
    // the host): both 0..1 and driven by advance()
    property real grouping: 0
    property real stage: 0
    property bool recalled: false
    // The beams' clock: runs only while sound plays (CentreWatch says so)
    readonly property bool playing: watch.item ? watch.item.playing : false
    property real beamTime: 0

    readonly property bool grouped: grouping > 0
    // How present the parts of the group are while the camera arrives (0..1)
    readonly property real presence: Centre.ease(grouping)
    // The parts that exist only for a group (the beams, the ring, the label)
    readonly property bool shown: grouped || wanted
    readonly property real _goalGrouping: wanted ? 1 : 0
    readonly property real _goalStage: recalled ? 1 : 0
    // The camera or the stage is still on its way: the loop keeps going, and
    // faster than the drift (60 Hz) so the voyage is smooth
    readonly property bool travelling: grouping !== _goalGrouping || stage !== _goalStage

    // --- Where things sit (Centre.js) --------------------------------------------
    readonly property var sizes: Centre.sizes(scene)
    readonly property var group: Centre.groupAt(scene, Centre.ease(stage))
    readonly property real away: Centre.away(grouping, stage)
    readonly property var host: Centre.hostAt(scene, away)
    readonly property bool hostAway: away > 0.5
    // The connected ring opens around the group so the other devices clear it
    readonly property real ringNorm: Centre.ringNorm(scene, scene.baseNorm, away)
    // The host's keep-out disc for the bodies of the outer belt
    readonly property var core: ({
            "x": host.x,
            "y": host.y,
            "r": scene.coreSize * 0.5 * host.scale
        })

    // The sky drifts a little the way the camera went: set once the voyage is
    // half done, and the starfield glides there (its own short transition)
    property var _origin: ({
            "x": 0,
            "y": 0
        })
    readonly property var shift: grouping > 0.5 && stage < 0.5 && scene.motion ? Centre.parallax(scene, _origin) : ({
            "x": 0,
            "y": 0
        })

    // The levels of the group: the ring's general one and each copy's own
    readonly property alias volume: levels
    CentreVolume {
        id: levels
        scene: centre.scene
        session: centre.session
    }

    // Whether sound plays: asked of PipeWire only while someone sees the group
    // move (awake, Reduce motion off), as nothing pulses otherwise
    Loader {
        id: watch
        active: centre.wanted && centre.scene.awake && centre.scene.motion
        sourceComponent: CentreWatch {
            node: centre.session.sharedNode
        }
    }

    function isMember(address) {
        return wanted && members.indexOf(address) >= 0;
    }
    // Body b sits in the group (not leaving, swallowed or on its way out)
    function holds(b) {
        return isMember(b.address) && !b.leaving && !b.swallowing;
    }
    // No tether to the host while the host is away; once it is recalled, the
    // devices outside the group get theirs back
    function tetherless(address) {
        return grouped && !(stage >= 1 && !isMember(address));
    }

    // Where a member of the group wants to be (null for anyone else), and its
    // role there. A held member writes its own depth and disc size.
    function target(b) {
        b.role = Centre.roleOf(isMember(b.address) ? members : [], source, b.address);
        if (!holds(b))
            return null;
        const sz = sizes, c = group;
        const snap = !scene.motion;
        if (b.role === "source") {
            b.depth = 1;
            b.roleDiameter = sz.source * c.scale;
            return {
                "x": c.x,
                "y": c.y,
                "k": 55,
                "zeta": 0.85,
                "snap": snap
            };
        }
        const slot = Centre.copySlot(sz.radius, c, copies.indexOf(b.address), copies.length, Centre.phaseAt(scene.orbitTime));
        b.depth = slot.depth;
        b.roleDiameter = sz.copy * c.scale * Centre.depthSize(slot.depth);
        return {
            "x": slot.x,
            "y": slot.y,
            "k": 45,
            "zeta": 0.75,
            "snap": snap
        };
    }

    // The disc of b grows to its role (or back to its ring size) at the pace
    // of the voyage; true while it still changes. Asleep it lands at once.
    function size(b, dt) {
        const goal = b.role ? 1 : 0;
        if (b.roleMix === goal)
            return false;
        b.roleMix = scene.awake ? Centre.approach(b.roleMix, goal, dt, scene.motion ? Centre.VOYAGE : Centre.FADE) : goal;
        return b.roleMix !== goal;
    }

    // One step of the scene's loop: the camera, the stage and the beams
    function advance(dt, driven) {
        const secs = scene.motion ? Centre.VOYAGE : Centre.FADE;
        const awake = scene.awake;
        grouping = awake ? Centre.approach(grouping, _goalGrouping, dt, secs) : _goalGrouping;
        stage = awake ? Centre.approach(stage, _goalStage, dt, Centre.RECALL) : _goalStage;
        if (driven && playing)
            beamTime += dt;
        _tidy();
    }

    // Back at rest with no group: nothing to keep, the parts unload
    function _tidy() {
        if (!wanted && grouping === 0 && members.length > 0) {
            members = [];
            source = "";
        }
    }

    // The host comes back to the centre and the group steps back, and the
    // other way round
    function recall() {
        if (!wanted || recalled)
            return;
        recalled = true;
        scene.wake();
    }
    function release() {
        if (!recalled)
            return;
        recalled = false;
        scene.wake();
    }

    // --- The session changes -------------------------------------------------------
    // Who is in, and which one is the source, as one text so the handler runs
    // when either changes and not each time the session updates
    readonly property string _key: wanted ? session.members.join(",") + "|" + session.source : ""
    on_KeyChanged: {
        if (wanted)
            _take();
        else
            recalled = false;
        if (!scene.awake) {
            // Nobody sees it: no voyage
            grouping = _goalGrouping;
            stage = _goalStage;
            _tidy();
        }
        scene.wake();
    }
    Component.onCompleted: if (wanted)
        _take()

    function _take() {
        const next = session.members.slice();
        // "" when the group is empty: a string property takes no undefined
        const src = session.source || next[0] || "";
        if (members.length === 0)
            _origin = _positionOf(src);
        members = next;
        source = src;
    }
    // The body of a device, null when there is none
    function bodyOf(address) {
        for (let i = 0; i < bodies.count; i++) {
            const b = bodies.itemAt(i);
            if (b && b.address === address)
                return b;
        }
        return null;
    }
    function _positionOf(address) {
        const b = bodyOf(address);
        return b ? {
            "x": b.px,
            "y": b.py
        } : {
            "x": scene.cx,
            "y": scene.cy
        };
    }
}
