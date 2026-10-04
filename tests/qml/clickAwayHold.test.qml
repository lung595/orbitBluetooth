import QtQuick
import "components/volume"

// Test of ClickAwayHold: it finds DMS's full-screen click-away layer among
// its host window's children by its shape; while held, that layer is
// hidden; once let go (a moment after release()), or gone with its owner,
// DMS's own value is back. The island's own motion is never touched, and
// nothing is ever written for good (value 12). Run with tests/qml/run.sh.
Item {
    id: h

    // DMS's click-away layer, mapped while the island is open: a window
    // with a mask and an exclusive zone, among other children of the host
    property bool open: true
    QtObject {
        id: screenLayer
        property bool visible: h.open
        property int exclusiveZone: -1
        property var mask: null
    }
    // Another child of the host, which is not the layer
    QtObject {
        id: decoy
        property bool visible: true
    }
    QtObject {
        id: screenHost
        property var data: [decoy, screenLayer]
    }
    ClickAwayHold {
        id: hold
        host: screenHost
        delay: 40
    }
    // A second layer, for an owner that goes while it holds (the face when
    // the plugin is turned off)
    property bool open2: true
    QtObject {
        id: screenLayer2
        property bool visible: h.open2
        property int exclusiveZone: -1
        property var mask: null
    }
    QtObject {
        id: screenHost2
        property var data: [screenLayer2]
    }
    // A host with nothing that looks like the layer (a DMS update)
    QtObject {
        id: bareHost
        property var data: [decoy]
    }
    Component {
        id: ownerMaker
        Item {
            id: owner
            required property var host
            property alias hold: inner
            ClickAwayHold {
                id: inner
                host: owner.host
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
                check("held: the layer is hidden, found by its shape", [screenLayer.visible, hold.held], [false, true]);
                check("held: the host's other children are left alone", decoy.visible, true);
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
                    "host": screenHost2
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
                    "host": null
                });
                h.owner.hold.hold();
                check("no host: nothing breaks", h.owner.hold.held, true);
                h.owner.destroy();
                h.owner = ownerMaker.createObject(h, {
                    "host": bareHost
                });
                h.owner.hold.hold();
                check("no layer in the host: nothing breaks, nothing hidden", [h.owner.hold.held, decoy.visible], [true, true]);
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
