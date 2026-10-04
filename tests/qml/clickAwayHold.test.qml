import QtQuick
import "components/volume"

// Test of ClickAwayHold: while held, DMS's full-screen click-away layer is
// hidden; once let go (a moment after release()), or gone with its owner,
// DMS's own value is back. The island's own motion is never touched, and
// nothing is ever written for good (value 12). Run with tests/qml/run.sh.
Item {
    id: h

    // DMS's click-away layer, mapped while the island is open
    property bool open: true
    QtObject {
        id: screenLayer
        property bool visible: h.open
    }
    ClickAwayHold {
        id: hold
        clickAway: screenLayer
        delay: 40
    }
    // A second layer, for an owner that goes while it holds (the face when
    // the plugin is turned off)
    property bool open2: true
    QtObject {
        id: screenLayer2
        property bool visible: h.open2
    }
    Component {
        id: ownerMaker
        Item {
            id: owner
            required property var clickAway
            property alias hold: inner
            ClickAwayHold {
                id: inner
                clickAway: owner.clickAway
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
            "run": () => check("at rest the layer follows DMS", [screenLayer.visible, hold.held], [true, false])
        },
        {
            "then": 0,
            "run": () => {
                hold.hold();
                check("held: the layer is hidden", [screenLayer.visible, hold.held], [false, true]);
                h.open = false;
                h.open = true;
                check("held: DMS mapping it again does not undo it", screenLayer.visible, false);
            }
        },
        {
            "then": 150,
            "run": () => {
                hold.release();
                check("just released: still hidden, the way out is as cheap", [screenLayer.visible, hold.held], [false, true]);
            }
        },
        {
            "then": 0,
            "run": () => {
                check("let go: the layer is mapped again", [screenLayer.visible, hold.held], [true, false]);
                h.open = false;
                check("and DMS's binding is alive", screenLayer.visible, false);
                h.open = true;
            }
        },
        {
            "then": 150,
            "run": () => {
                hold.hold();
                hold.release();
                hold.hold();
            }
        },
        {
            "then": 150,
            "run": () => {
                check("a new hold cancels the release", [screenLayer.visible, hold.held], [false, true]);
                hold.release();
            }
        },
        {
            "then": 50,
            "run": () => {
                check("released for good: the layer is back", [screenLayer.visible, hold.held], [true, false]);
                h.owner = ownerMaker.createObject(h, {
                    "clickAway": screenLayer2
                });
                h.owner.hold.hold();
                check("a second owner holds its own layer", screenLayer2.visible, false);
                h.owner.destroy();
            }
        },
        {
            "then": 50,
            "run": () => {
                check("gone while holding: DMS's value is back, not the held one", screenLayer2.visible, true);
                h.open2 = false;
                check("and its binding is alive", screenLayer2.visible, false);
                h.open2 = true;
                h.owner = ownerMaker.createObject(h, {
                    "clickAway": null
                });
                h.owner.hold.hold();
                check("no layer to hold: nothing breaks", h.owner.hold.held, true);
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
