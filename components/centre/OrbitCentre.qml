import QtQuick
import "Centre.js" as Centre
import "Perspective.js" as Perspective
import "Sun.js" as Sun

// The scene while a Listen together takes the centre (D281-D285): the source
// planet in the middle with its copies orbiting it, and the host revolving
// around the group like a sun, its ring and belt of devices with it, smaller
// when it is behind and bigger when it is in front. This is the state, and
// the answers the parts ask (where a member sits, how big it is, where the
// host is, in which geometry a device is dragged). It owns no timer:
// OrbitPhysics calls advance() on its own step, so the voyage, the orbit, the
// sun and the beams ride the one loop that already stops when nobody looks.
// With Reduce motion nothing keeps turning: the group lands with a short
// fade and the sun stays where it rests.
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
    // The group has the centre and Fedora's view is not the one shown
    readonly property bool canRecall: wanted && !recalled
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

    // --- Where things sit (Centre.js, Sun.js) ------------------------------------
    // The scene is seen in profile (Perspective.js) as the camera arrives, in
    // both views; `flat` is its geometry then, the scene itself with no group
    readonly property real profile: presence
    readonly property var flat: Perspective.flat(scene, profile)
    readonly property var sizes: Centre.sizes(scene)
    // Fedora's view puts the group on a slot of the host's ring: the physics
    // step lays the ring out and hands the slot over (place)
    property var _slot: ({
            "x": 0,
            "y": 0,
            "depth": 1
        })
    readonly property var group: Centre.groupAt(scene, Centre.ease(stage), _slot)
    readonly property real away: Centre.away(grouping, stage)
    // The sun's angle on its path (it starts at its rest spot and stays there
    // with Reduce motion) and how fast it goes, 0..1: it slows to a stop under
    // a dragged device and sets off again after it
    property real sunPhase: Sun.REST
    property real _sunSpeed: 1
    // Where the host's system is: its centre, its scale and its depth
    readonly property var system: Sun.system(scene, sunPhase, away)
    readonly property var host: ({
            "x": system.x,
            "y": system.y,
            "scale": system.k
        })
    readonly property bool hostAway: away > 0.5
    // The host's keep-out disc for the bodies of the outer belt
    readonly property var core: ({
            "x": host.x,
            "y": host.y,
            "r": scene.coreSize * 0.5 * host.scale
        })
    // The stacking order of the host and of the group (Sun.js): they sort by
    // height among the bodies, and the group is over the host's whole system
    // once it has the centre
    readonly property real hostZ: Sun.hostZ(host, grouped)
    readonly property real groupZ: Sun.groupZ(group, away)

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
    // The members of the group have no tether to the host (they are the
    // centre now); the devices outside it keep theirs to the sun
    function tetherless(address) {
        return grouped && members.indexOf(address) >= 0;
    }

    // The scene's geometry as the devices outside the group live in it: the
    // sun's, with the connected ring and the belt around it. The scene itself
    // while the group is not there.
    function sunGeometry() {
        return away > 0 ? Sun.view(flat, system) : flat;
    }
    // ...and the group's, for a member that is dragged out of it
    function groupGeometry() {
        return Sun.groupView(flat, sizes, group);
    }
    // The slot the group takes on the host's ring (Physics.ringSlot); of no use
    // while the group keeps the centre, so it is not kept then
    function place(slot) {
        if (stage > 0)
            _slot = slot;
    }
    // The geometry a body is dragged in: its group's, or the sun's
    function geometryOf(b) {
        return holds(b) ? groupGeometry() : sunGeometry();
    }

    // Where a member of the group wants to be (null for anyone else), and its
    // role there. A held member writes its own depth and disc size, which
    // grows to its role at the pace of the voyage (a new source does not pop).
    function target(b, dt) {
        b.role = Centre.roleOf(isMember(b.address) ? members : [], source, b.address);
        if (!holds(b))
            return null;
        const sz = sizes, c = group;
        const snap = !scene.motion;
        const grow = goal => snap ? goal : Centre.grow(b.roleDiameter, goal, sz.source * c.scale, dt, Centre.VOYAGE);
        if (b.role === "source") {
            b.depth = 1;
            b.roleDiameter = grow(sz.source * c.scale);
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
        b.roleDiameter = grow(sz.copy * c.scale * Centre.depthSize(slot.depth));
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

    // One step of the scene's loop: the camera, the stage, the sun and the beams
    function advance(dt, driven) {
        const secs = scene.motion ? Centre.VOYAGE : Centre.FADE;
        const awake = scene.awake;
        grouping = awake ? Centre.approach(grouping, _goalGrouping, dt, secs) : _goalGrouping;
        stage = awake ? Centre.approach(stage, _goalStage, dt, scene.motion ? Centre.RECALL : Centre.FADE) : _goalStage;
        if (driven && grouped) {
            _sunSpeed = Centre.approach(_sunSpeed, scene.dragBody ? 0 : 1, dt, Sun.STOP);
            sunPhase = Sun.advance(sunPhase, dt, Centre.ease(_sunSpeed));
        }
        if (driven && playing)
            beamTime += dt;
        _tidy();
    }

    // Back at rest with no group: nothing to keep, the parts unload, and the
    // sun starts from its rest spot next time
    function _tidy() {
        if (wanted || grouping > 0)
            return;
        if (members.length > 0) {
            members = [];
            source = "";
        }
        // Whether the session emptied its list before it ended or not
        sunPhase = Sun.REST;
        _sunSpeed = 1;
    }

    // The host comes back to the centre and the group steps back, and the
    // other way round
    function recall() {
        if (!canRecall)
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
