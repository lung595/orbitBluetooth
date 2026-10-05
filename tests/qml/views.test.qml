import QtQuick
import QtTest
import qs.Common
import qs.Services
import "components/centre"
import "components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Test of the click on the empty sky that steps back one level (D294): while
// a Listen together has the centre, the group can step back to give it to the
// host (canRecall, recall()) but only once; a popout that closes reopens on
// the view it had (D297); the click's order is the card first, then Fedora's
// view (OrbitFocus.stepBack); and a real click on the sky of a real scene
// does that, and falls through to what lies below while there is nothing to
// step back from (the backdrop's click area is enabled only then). The first
// parts run on stand-ins for the scene, the last on the scene itself with
// real mouse events (QtTest). Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string two: "02:00:00:00:20:02"

    FakeRoute {
        id: route
    }

    // --- Stand-ins, for the parts that run on their own ------------------------------
    // The part of the scene the centre and the focus control read
    QtObject {
        id: stub
        property var prefs: ({
                "togetherCentre": true
            })
        // Whether the popout is open; the centre itself does not read it
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
        // What OrbitFocus.stepBack reads and calls
        property var focusBody: null
        property bool hiddenOpen: false
        property bool renaming: false
        property bool menuOpen: false
        // The volume radar, never open on this stand-in
        readonly property var radar: QtObject {
            property bool open: false
            function close() {
            }
        }
        property int hiddenClosed: 0
        property var centre: centreItem
        function wake() {
            wakes++;
        }
        function explain(n) {
            notes = notes.concat([n]);
            note = n;
        }
        function closeHidden() {
            hiddenClosed++;
            hiddenOpen = false;
        }
        function forceActiveFocus() {
        }
    }
    Repeater {
        id: noBodies
        model: 0
    }
    OrbitCentre {
        id: centreItem
        scene: stub
        bodies: noBodies
        session: route.together
    }
    OrbitFocus {
        id: focusCtl
        scene: stub
        menu: QtObject {}
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // The scene's step, as OrbitPhysics calls it: `seconds` of 0.1 s steps
    function run(seconds) {
        for (let i = 0; i < Math.round(seconds * 10); i++)
            centreItem.advance(0.1, true);
    }
    // Back to a quiet start: no group, nothing stepped back, the stage at rest
    function reset() {
        route.sharing = [];
        run(1);
        centreItem.release();
        run(1);
        stub.active = true;
        stub.focusBody = null;
        stub.hiddenOpen = false;
    }

    function canRecall() {
        check("no group: there is nothing to step back from", [centreItem.wanted, centreItem.canRecall], [false, false]);
        route.sharing = [h.headset, h.one, h.two];
        check("a group has the centre: it can step back (counter-proof)", [centreItem.wanted, centreItem.recalled, centreItem.canRecall], [true, false, true]);
        centreItem.recall();
        check("stepped back: it cannot step back again", [centreItem.recalled, centreItem.canRecall], [true, false]);
        centreItem.release();
        check("let back to the centre: it can step back again", [centreItem.recalled, centreItem.canRecall], [false, true]);
    }

    function recall() {
        reset();
        const woken = stub.wakes;
        centreItem.recall();
        check("no group: the recall does nothing and wakes nothing", [centreItem.recalled, stub.wakes], [false, woken]);
        route.sharing = [h.headset, h.one, h.two];
        run(1);
        const before = stub.wakes;
        centreItem.recall();
        check("a group: the recall is set and the loop is woken", [centreItem.recalled, stub.wakes > before], [true, true]);
        check("the stage is on its way, not there yet", [centreItem.stage, centreItem.travelling], [0, true]);
        run(1);
        check("then the group is at the back", [centreItem.stage, centreItem.travelling], [1, false]);
    }

    // A popout that closes (a click outside it does that) opens again on the
    // view it had: the group's if it had the centre, Fedora's if it had stepped
    // back (D297). Closing changes nothing, so nothing is recalled and nothing
    // moves while nobody looks.
    function closing() {
        reset();
        route.sharing = [h.headset, h.one, h.two];
        run(1);
        stub.active = false;
        check("closed on the group's view: it keeps the centre", [centreItem.recalled, centreItem.stage], [false, 0]);
        stub.active = true;
        check("opened again: still the group's view", [centreItem.recalled, centreItem.stage], [false, 0]);

        // Stepped back to Fedora's view before closing: it opens on that view
        centreItem.recall();
        run(1);
        stub.active = false;
        stub.active = true;
        check("closed on Fedora's view: it opens on Fedora's view", [centreItem.recalled, centreItem.stage], [true, 1]);

        // The group ends: the next one starts at the centre again
        route.sharing = [];
        run(1);
        check("the group ends: the recall is forgotten", [centreItem.recalled, centreItem.canRecall], [false, false]);

        // No group: closing and opening leave the centre as it is
        stub.active = false;
        stub.active = true;
        check("no group: nothing is recalled", [centreItem.recalled, centreItem.stage], [false, 0]);
    }

    function stepBack() {
        reset();
        route.sharing = [h.headset, h.one, h.two];
        run(1);
        stub.focusBody = {
            "leaving": false
        };
        focusCtl.stepBack();
        check("a card is open: the click closes it first", [stub.focusBody, centreItem.recalled], [null, false]);
        focusCtl.stepBack();
        check("the next click steps back to Fedora's view", [stub.focusBody, centreItem.recalled], [null, true]);
        centreItem.release();

        // The hidden list is a level too, and goes before the group's view
        stub.hiddenOpen = true;
        const closed = stub.hiddenClosed;
        focusCtl.stepBack();
        check("the hidden list is open: the click closes it, not the group's view", [stub.hiddenOpen, stub.hiddenClosed - closed, centreItem.recalled], [false, 1, false]);

        // With no group there is only the card to step back from
        stub.focusBody = {
            "leaving": false
        };
        route.sharing = [];
        run(1);
        focusCtl.stepBack();
        focusCtl.stepBack();
        check("no group: the card closes, and the next click does nothing", [stub.focusBody, centreItem.recalled], [null, false]);
    }

    // --- The real scene, with real mouse events ---------------------------------------
    // A click area under the scene, to see whether a click falls through it
    property int fellThrough: 0
    MouseArea {
        anchors.fill: parent
        onClicked: h.fellThrough++
    }
    OrbitScene {
        id: scene
        anchors.fill: parent
        active: true
        autoScan: false
        previewDevices: Devices.list(false, 2)
        audioRoute: route
    }
    // Only here for its mouse events: left to run (`when` true) it would find
    // no test function, finish and quit the whole test before the steps
    TestCase {
        id: mouse
        name: "views"
        when: false
    }
    // An empty corner of the sky: no planet, card or chip lies there
    function clickSky() {
        mouse.mouseClick(scene, 12, scene.height - 12);
    }

    // Each step runs, then waits `then` ms before the next
    readonly property var steps: [
        {
            "then": 400,
            "run": () => {
                // Reduce motion: the group is put in place at once
                SettingsData.reduceMotion = true;
            }
        },
        {
            "then": 100,
            "run": () => {
                check("no group: nothing to step back from", scene.canStepBack, false);
                h.clickSky();
                check("so a click on the sky falls through to what is below", [h.fellThrough, scene.centre.recalled], [1, false]);
                route.sharing = [h.headset, h.one, h.two];
            }
        },
        {
            "then": 800,
            "run": () => {
                check("a group has the centre: the sky can step back", [scene.centre.shown, scene.canStepBack], [true, true]);
                h.clickSky();
                check("a click on the sky steps back to Fedora's view, and the click stays here", [scene.centre.recalled, h.fellThrough], [true, 1]);
                check("stepped back: the sky has nothing more to step back from", scene.canStepBack, false);
                h.clickSky();
                check("so the next click falls through", [h.fellThrough, scene.centre.recalled], [2, true]);
            }
        },
        {
            "then": 100,
            "run": () => {
                // A card over the group's view: the click closes it first
                scene.centre.release();
                // The detail card of a group member is the radar's Details, a plain click opens the radar
                scene.focusOn(scene.centre.bodyOf(h.headset), true);
                check("a card is open over the group", [!!scene.focusBody, scene.centre.recalled], [true, false]);
                h.clickSky();
                check("a click on the sky closes the card, and Fedora's view stays away", [scene.focusBody, scene.centre.recalled, h.fellThrough], [null, false, 2]);
                h.clickSky();
                check("the next click steps back to Fedora's view", [scene.centre.recalled, h.fellThrough], [true, 2]);
            }
        }
    ]
    property int step: 0
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 20000
        running: true
        onTriggered: {
            print("FAIL timed out at step " + h.step);
            Qt.exit(1);
        }
    }
    Timer {
        id: clock
        onTriggered: h.next()
    }
    function next() {
        if (step >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        const s = steps[step++];
        s.run();
        clock.interval = s.then;
        clock.start();
    }
    Component.onCompleted: {
        canRecall();
        recall();
        closing();
        stepBack();
        PluginService.globalVars = State.globals("orbit", Date.now());
        Qt.callLater(next);
    }
}
