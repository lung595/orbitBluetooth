import QtQuick
import "components/volume"

// Test of IslandSnap: while held, a stand-in for DMS's island follows at
// once, whatever the user's own Reduce Motion setting says; once let go
// (a moment after release()), or gone with its owner, DMS's own binding
// is back and alive. Nothing of the island is ever written for good
// (value 12). Run with tests/qml/run.sh.
Item {
    id: h

    // The user's Reduce Motion switch, bound the way DMS binds the island's
    property bool user: false
    QtObject {
        id: island
        property bool reducedMotion: h.user
        property real springStiffness: 560
    }
    IslandSnap {
        id: snap
        surface: island
        delay: 40
    }
    // A second island, for an owner that goes while it holds (the face when
    // the plugin is turned off)
    property bool user2: false
    QtObject {
        id: island2
        property bool reducedMotion: h.user2
    }
    Component {
        id: ownerMaker
        Item {
            id: owner
            required property var island
            property alias snap: inner
            IslandSnap {
                id: inner
                surface: owner.island
                delay: 40
            }
        }
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // Each step says how long to wait before the next one, so that the
    // release timer can run
    readonly property var steps: [
        {
            "then": 0,
            "run": () => check("at rest the island follows the user's setting", [island.reducedMotion, snap.held], [false, false])
        },
        {
            "then": 0,
            "run": () => {
                snap.hold();
                check("held: the island follows at once", [island.reducedMotion, snap.held], [true, true]);
                h.user = true;
                h.user = false;
                check("held: the user's own toggles do not undo it", island.reducedMotion, true);
            }
        },
        {
            "then": 150,
            "run": () => {
                snap.release();
                check("just released: still at once, the way out is as cheap", [island.reducedMotion, snap.held], [true, true]);
            }
        },
        {
            "then": 0,
            "run": () => {
                check("let go: DMS's setting is back", [island.reducedMotion, snap.held], [false, false]);
                h.user = true;
                check("and its binding is alive", island.reducedMotion, true);
                h.user = false;
            }
        },
        {
            "then": 150,
            "run": () => {
                snap.hold();
                snap.release();
                snap.hold();
            }
        },
        {
            "then": 150,
            "run": () => {
                check("a new hold cancels the release", [island.reducedMotion, snap.held], [true, true]);
                snap.release();
            }
        },
        {
            "then": 50,
            "run": () => {
                check("released for good: DMS's setting is back", [island.reducedMotion, snap.held], [false, false]);
                h.owner = ownerMaker.createObject(h, {
                    "island": island2
                });
                h.owner.snap.hold();
                check("a second owner holds its own island", island2.reducedMotion, true);
                h.owner.destroy();
            }
        },
        {
            "then": 50,
            "run": () => {
                check("gone while holding: DMS's setting is back, not the held value", island2.reducedMotion, false);
                h.user2 = true;
                check("and its binding is alive", island2.reducedMotion, true);
                h.user2 = false;
                // The same, with the user's switch on while the island is held
                h.owner = ownerMaker.createObject(h, {
                    "island": island2
                });
                h.owner.snap.hold();
                h.user2 = true;
                h.owner.destroy();
            }
        },
        {
            "then": 50,
            "run": () => {
                check("gone while the user turned it on: it stays on", island2.reducedMotion, true);
                h.user2 = false;
                check("and follows the user again", island2.reducedMotion, false);
                h.owner = ownerMaker.createObject(h, {
                    "island": null
                });
                h.owner.snap.hold();
                check("no island to hold: nothing breaks", h.owner.snap.held, true);
                h.owner.destroy();
            }
        }
    ]
    property var owner: null
    property int at: 0

    Timer {
        id: clock
        onTriggered: h.next()
    }
    function next() {
        if (at >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        const step = steps[at++];
        step.run();
        clock.interval = Math.max(1, step.then);
        clock.start();
    }
    Component.onCompleted: Qt.callLater(next)
}
