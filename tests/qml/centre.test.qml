import QtQuick
import Quickshell.Services.Pipewire
import qs.Common
import "components/centre"
import "components/centre/Sun.js" as Sun
import "mock"

// Test of OrbitCentre and CentreVolume (D281-D285): while the setting allows it
// and a Listen together is on, the group takes the centre (the camera's voyage
// is a fade with Reduce motion and nothing at all while nobody looks), the
// source sits in the middle, its copies on an even tilted orbit, the host
// revolving around them like a sun (smaller behind, bigger in front, fixed with
// Reduce motion) with the devices outside the group; the beams' clock runs only while sound plays and the scene is
// awake with motion on; the ring's general volume moves every member and keeps
// the gaps, a wheel over a copy moves its own level or says why it cannot
// instead of staying silent (value 10). The scene is a stand-in with only what
// the centre reads. Run with tests/qml/run.sh.
Item {
    id: h

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string two: "02:00:00:00:20:02"
    readonly property string stranger: "02:00:00:00:30:09"

    FakeRoute {
        id: route
    }
    // The part of the scene the centre reads
    QtObject {
        id: scene
        property var prefs: ({
                "togetherCentre": true
            })
        property bool active: true
        property bool awake: true
        property bool motion: true
        property real orbitTime: 0
        property var deviceMap: ({})
        property var note: null
        property var notes: []
        property int wakes: 0
        property var dragBody: null
        readonly property real cx: 260
        readonly property real cy: 220
        readonly property real rx: 213
        readonly property real ry: 146
        readonly property real ringRy: ry * innerNorm * 0.8
        readonly property real ringCy: cy + ry * innerNorm * 0.2
        readonly property real innerNorm: 0.56
        readonly property real snapNorm: 0.7
        readonly property real detachNorm: 0.8
        readonly property real outerMinNorm: 0.8
        readonly property real holeX: cx
        readonly property real holeY: cy + ry
        readonly property real holeHorizon: 30
        readonly property real coreSize: 75
        readonly property real bodySize: 59
        function wake() {
            wakes++;
        }
        function explain(n) {
            notes = notes.concat([n]);
            note = n;
        }
    }
    Repeater {
        id: noBodies
        model: 0
    }
    OrbitCentre {
        id: centre
        scene: scene
        bodies: noBodies
        session: route.together
    }

    // A session whose members have no shared filter: each plays at its own level
    component Level: QtObject {
        property real volume: 0.5
        property bool muted: false
    }
    component Node: QtObject {
        property Level audio: Level {}
    }
    readonly property var plainNodes: ({
            "02:00:00:00:10:06": nodeA,
            "02:00:00:00:20:01": nodeB,
            "02:00:00:00:20:02": nodeC
        })
    Node {
        id: nodeA
        audio: Level {
            volume: 0.5
        }
    }
    Node {
        id: nodeB
        audio: Level {
            volume: 0.4
        }
    }
    Node {
        id: nodeC
        audio: Level {
            volume: 0.3
        }
    }
    QtObject {
        id: plain
        readonly property var route: route
        readonly property var members: [h.headset, h.one, h.two]
        readonly property bool active: true
        readonly property string source: h.headset
        readonly property var sharedNode: null
        readonly property var sharedNodes: []
        function memberNode(address) {
            return h.plainNodes[address] || null;
        }
        function nameOf(address) {
            return "Name " + address.slice(-2);
        }
    }
    CentreVolume {
        id: shared
        scene: scene
        session: route.together
    }
    CentreVolume {
        id: split
        scene: scene
        session: plain
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function near(a, b, eps) {
        return Math.abs(a - b) <= (eps === undefined ? 1e-6 : eps);
    }
    // The scene's step, as OrbitPhysics calls it: `seconds` of 0.1 s steps
    function run(seconds, driven) {
        for (let i = 0; i < Math.round(seconds * 10); i++)
            centre.advance(0.1, driven);
    }
    function body(address) {
        return {
            "address": address,
            "leaving": false,
            "swallowing": false,
            "role": "",
            "depth": 0,
            "roleDiameter": 0
        };
    }

    function forming() {
        check("no session: nothing is wanted, shown or moving", [centre.wanted, centre.shown, centre.grouping, centre.travelling], [false, false, 0, false]);
        route.sharing = [h.headset, h.one, h.two];
        check("a session: the group is wanted and shown", [centre.wanted, centre.shown], [true, true]);
        check("the source is the first, the copies the others", [centre.source, centre.copies], [h.headset, [h.one, h.two]]);
        check("the loop is woken to show the voyage", [scene.wakes > 0, centre.travelling], [true, true]);
        run(0.4, true);
        check("the voyage is half done after half of its time", near(centre.grouping, 0.5, 0.001), true);
        run(0.5, true);
        check("then it has landed: the loop may rest", [centre.grouping, centre.travelling], [1, false]);
        check("the group is whole in the middle of the view", [centre.group.scale, centre.group.x, centre.group.y], [1, 260, 220]);
        const s = Sun.system(scene, centre.sunPhase, 1);
        check("the host is the sun's system: its place and its size", [centre.host.x, centre.host.y, centre.host.scale], [s.x, s.y, s.k]);
        check("the sun starts at its rest spot and has turned with the time that passed", near(centre.sunPhase, Sun.REST + 0.9 / Sun.PERIOD * 2 * Math.PI), true);
        check("it is smaller than the host was alone, and off the middle", [centre.host.scale < 1, centre.host.x !== 260 && centre.host.y !== 220], [true, true]);
        check("the host keeps out a disc at its size", near(centre.core.r, 75 * 0.5 * centre.host.scale), true);
    }

    function places() {
        const s = body(h.headset), c1 = body(h.one), c2 = body(h.two), x = body("02:00:00:00:99:99");
        const ts = centre.target(s), t1 = centre.target(c1), t2 = centre.target(c2);
        check("the source is held in the middle at its size", [s.role, ts.x, ts.y, s.roleDiameter, ts.snap], ["source", 260, 220, centre.sizes.source, false]);
        check("a copy is held on the orbit", [c1.role, c2.role], ["copy", "copy"]);
        const r = centre.sizes.radius;
        check("a copy sits on the tilted orbit", near(Math.hypot((t1.x - 260) / r, (t1.y - 220) / (r * 0.55)), 1, 1e-6), true);
        check("two copies are opposite each other", [near(t1.x + t2.x, 520), near(t1.y + t2.y, 440)], [true, true]);
        check("depth tells the near side", [Math.abs(c1.depth + c2.depth) < 1e-6, Math.abs(c1.depth) <= 1], [true, true]);
        check("a copy is a little smaller on the far side", (c1.depth < c2.depth) === (c1.roleDiameter < c2.roleDiameter), true);
        check("a device outside the group is not held", [centre.target(x), x.role], [null, ""]);
        const gone = body(h.one);
        gone.leaving = true;
        check("a member on its way out is let go", [centre.target(gone), gone.role], [null, "copy"]);
        check("members have no tether to the host, the others keep theirs", [centre.tetherless(h.one), centre.tetherless("02:00:00:00:99:99")], [true, false]);
    }

    // The solar system (value 6, 9): the group stays in the middle of the view
    // and the others turn around the sun, not around the middle
    function sun() {
        route.sharing = [h.headset, h.one, h.two];
        run(1, true);
        const member = body(h.one), other = body("02:00:00:00:99:99");
        centre.target(member, 0.1);
        const sunView = centre.sunGeometry(), groupView = centre.groupGeometry();
        check("a device outside the group lives around the sun", [centre.geometryOf(other).cx, centre.geometryOf(other).cy, sunView.cx, sunView.cy], [centre.host.x, centre.host.y, centre.host.x, centre.host.y]);
        check("a member is dragged in the group's own geometry, in the middle", [centre.geometryOf(member).cx, centre.geometryOf(member).cy, groupView.cx, groupView.cy], [260, 220, 260, 220]);
        check("the sun's view is the host's size", [sunView.rx, sunView.coreSize], [scene.rx * centre.host.scale, scene.coreSize * centre.host.scale]);
        check("the group's ring is the copies' orbit", [groupView.ringCy, near(groupView.ringRy, centre.sizes.radius * 0.55)], [220, true]);
        // It turns while the scene's time runs (counter-proof: not without it)
        let before = centre.sunPhase;
        run(1, true);
        check("the sun moves while the time runs", centre.sunPhase > before, true);
        const spot = [centre.host.x, centre.host.y];
        before = centre.sunPhase;
        run(1, false);
        check("and stays where it is while the time is stopped (Reduce motion, asleep)", [centre.sunPhase, [centre.host.x, centre.host.y]], [before, spot]);
        check("the group does not move for it", [centre.group.x, centre.group.y, centre.target(member, 0.1) === null], [260, 220, false]);
        // It slows to a stop under a dragged device, then goes on
        scene.dragBody = member;
        run(1, true);
        before = centre.sunPhase;
        run(1, true);
        check("the sun stops under a dragged device", centre.sunPhase, before);
        scene.dragBody = null;
        run(1, true);
        check("and sets off again after it", centre.sunPhase > before, true);
    }

    function beams() {
        centre.beamTime = 0;
        Pipewire.playing = true;
        check("sound plays: the watch says so", centre.playing, true);
        centre.advance(0.1, true);
        check("the beams' clock runs with sound", near(centre.beamTime, 0.1), true);
        centre.advance(0.1, false);
        check("not while the scene's time is stopped", near(centre.beamTime, 0.1), true);
        Pipewire.playing = false;
        check("silence: the watch says so", centre.playing, false);
        centre.advance(0.1, true);
        check("the clock stops in silence (counter-proof)", near(centre.beamTime, 0.1), true);
        Pipewire.playing = true;
        scene.awake = false;
        check("asleep: nothing is watched", centre.playing, false);
        centre.advance(0.1, true);
        check("asleep: the clock does not run", near(centre.beamTime, 0.1), true);
        scene.awake = true;
        scene.motion = false;
        check("Reduce motion: nothing is watched", centre.playing, false);
        centre.advance(0.1, true);
        check("Reduce motion: the clock does not run", near(centre.beamTime, 0.1), true);
        scene.motion = true;
        check("awake with motion again: it plays", centre.playing, true);
    }

    function reduceMotion() {
        scene.motion = false;
        check("Reduce motion: a member is put in place, not flown there", centre.target(body(h.one)).snap, true);
        scene.motion = true;
        check("with motion it flies (counter-proof)", centre.target(body(h.one)).snap, false);
        // The group goes: with motion the camera takes its time...
        route.sharing = [];
        run(0.3, true);
        check("with motion the group fades out over the voyage", near(centre.grouping, 1 - 0.3 / 0.8, 0.001), true);
        route.sharing = [h.headset, h.one, h.two];
        run(1, true);
        // ... and with Reduce motion it is a short fade
        scene.motion = false;
        route.sharing = [];
        run(0.3, true);
        check("Reduce motion: the fade is over in its short time", [centre.grouping, centre.members], [0, []]);
        scene.motion = true;
    }

    function asleep() {
        scene.awake = false;
        route.sharing = [h.headset, h.one];
        check("asleep: nobody sees it, no voyage", [centre.grouping, centre.travelling], [1, false]);
        route.sharing = [];
        check("asleep: it is gone at once, nothing kept", [centre.grouping, centre.members, centre.shown], [0, [], false]);
        scene.awake = true;
    }

    function settingAndRecall() {
        route.sharing = [h.headset, h.one];
        run(1, true);
        scene.prefs = ({
                "togetherCentre": false
            });
        check("the setting off: a session does not take the centre", [centre.wanted, centre.target(body(h.one))], [false, null]);
        scene.prefs = ({
                "togetherCentre": true
            });
        check("the setting on: it does", centre.wanted, true);
        run(1, true);
        centre.recall();
        check("a click on the host: the group steps back", centre.recalled, true);
        run(0.5, true);
        check("the host is back in the middle, the group small at the back", [centre.stage, centre.host.scale, centre.group.scale], [1, 1, 0.5]);
        check("the others have their tether again, the group has none", [centre.tetherless("02:00:00:00:99:99"), centre.tetherless(h.one)], [false, true]);
        centre.release();
        // A little over its time: the steps add up to it only within rounding
        run(0.6, true);
        check("a click on the group: it takes the centre back", [centre.recalled, centre.stage, centre.host.scale], [false, 0, Sun.system(scene, centre.sunPhase, 1).k]);
        route.sharing = [];
        run(1, true);
        check("the group ends: the parts unload", [centre.shown, centre.members], [false, []]);
        check("and the next group's sun starts from its rest spot again", centre.sunPhase, Sun.REST);
    }

    function volumes() {
        route.sharing = [h.headset, h.one, h.two];
        check("shared: the general level is the PC's", [shared.shared, shared.ready, shared.level], [true, true, 0.85]);
        const held = SessionData.quiet;
        shared.set(0.6);
        check("shared: it reaches every copy", [route.shared.audio.volume, route.copyOne.audio.volume], [0.6, 0.6]);
        shared.set(0.612);
        check("a drag lands on whole percents", near(route.shared.audio.volume, 0.61), true);
        shared.set(0.614);
        check("a drag that changes nothing writes nothing, and keeps DMS's pop-up for itself only when it does", [near(route.shared.audio.volume, 0.61), SessionData.quiet - held], [true, 2]);
        shared.step(1);
        check("a wheel notch is one step", near(route.shared.audio.volume, 0.66), true);
        const kept = route.shared.audio.volume;
        const asked = SessionData.quiet;
        shared.toggleMute();
        check("the speaker mutes the group and keeps its level", [shared.muted, route.shared.audio.muted, route.copyOne.audio.muted, route.shared.audio.volume, SessionData.quiet], [true, true, true, kept, asked + 1]);
        shared.toggleMute();
        check("pressed again it lets the group speak", [shared.muted, route.shared.audio.muted, route.copyOne.audio.muted], [false, false, false]);

        check("split: the general level is the loudest's", [split.shared, split.level], [false, 0.5]);
        split.set(0.8);
        check("split: every level is scaled, the gaps kept", [nodeA.audio.volume, nodeB.audio.volume, nodeC.audio.volume].map(v => Math.round(v * 100) / 100), [0.8, 0.64, 0.48]);
        split.set(1.2);
        check("split: no one passes 100 %", [nodeA.audio.volume, nodeB.audio.volume > 0.7], [1, true]);
        nodeA.audio.volume = nodeB.audio.volume = nodeC.audio.volume = 0;
        split.set(0.4);
        check("all silent: there are no gaps, all come up", [nodeA.audio.volume, nodeB.audio.volume, nodeC.audio.volume], [0.4, 0.4, 0.4]);

        const quiet = SessionData.quiet;
        const before = route.shared.audio.volume;
        shared.turn(h.headset, 1);
        check("a wheel over the source moves the general level", [route.shared.audio.volume > before, SessionData.quiet], [true, quiet + 1]);
        check("a copy has a level of its own", [shared.ownLevel(h.one), shared.ownLevel(h.stranger)], [0.3, -1]);
        shared.turn(h.one, 1);
        check("a wheel over a copy moves its own", near(route.otherOne.audio.volume, 0.35), true);
        check("and DMS's pop-up waits for it too", SessionData.quiet, quiet + 2);
        check("and not the others", route.shared.audio.volume > before && route.otherTwo.audio.volume === 0.8, true);
        shared.turn(h.stranger, 1);
        check("a copy with none says why, with the way to the guide", [scene.notes.length, scene.notes[0].anchor, scene.notes[0].title.endsWith("has no volume of its own")], [1, "the-volume-at-the-center", true]);
        shared.turn(h.stranger, 1);
        check("and says it once while the note shows", scene.notes.length, 1);

        route.sharing = [];
        const level = route.shared.audio.volume;
        shared.set(0.2);
        check("no group: nothing is written", [shared.ready, route.shared.audio.volume], [false, level]);
        shared.toggleMute();
        check("no group: the speaker mutes nothing", route.shared.audio.muted, false);
    }

    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 20000
        running: true
        onTriggered: {
            print("FAIL timed out: a step threw");
            Qt.exit(1);
        }
    }

    Component.onCompleted: {
        forming();
        places();
        sun();
        beams();
        reduceMotion();
        asleep();
        settingAndRecall();
        volumes();
        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
