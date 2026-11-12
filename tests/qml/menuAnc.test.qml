import QtQuick
import "components/scene"

// Test of OrbitMenu and noise control (audit 2026-11): opening the menu on a
// headset with noise control takes a view of its mode; closing it gives the
// view back, and so does destroying the menu while it is open (the popout or
// the Control Center went away), so the helper does not keep running for
// nobody. Made-up scene and address. Run with tests/qml/run.sh.
Item {
    id: h
    width: 400
    height: 300

    property var calls: []
    QtObject {
        id: service
        function watch(address, on) {
            h.calls = h.calls.concat([address + (on ? "+" : "-")]);
        }
    }
    Item {
        id: fakeScene
        anchors.fill: parent
        readonly property bool motion: false
        readonly property var ancService: service
        readonly property var together: QtObject {
            function isMember(a) {
                return false;
            }
            function canGroup(b) {
                return false;
            }
            function members() {
                return [];
            }
        }
        function ancWatch(a, on) {
            service.watch(a, on);
        }
        function ancFor(a) {
            return null;
        }
    }
    readonly property var body: ({
            "address": "00:00:00:00:00:01",
            "ancCapable": true,
            "device": {},
            "connected": true,
            "phase": "connected",
            "paired": true
        })
    Component {
        id: menuMaker
        OrbitMenu {
            scene: fakeScene
        }
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    property var menu: null
    readonly property var steps: [
        () => {
            menu = menuMaker.createObject(fakeScene);
            menu.popup(body, Qt.point(10, 10));
            menu.close();
            check("open then close: the view is taken and given back", calls, ["00:00:00:00:00:01+", "00:00:00:00:00:01-"]);
            calls = [];
            menu.popup(body, Qt.point(10, 10));
            menu.destroy();
        },
        () => {
            check("destroyed while open: the view is given back too", calls, ["00:00:00:00:00:01+", "00:00:00:00:00:01-"]);
        }
    ]
    property int at: 0
    Timer {
        id: clock
        interval: 50
        onTriggered: h.next()
    }
    function next() {
        if (at >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        steps[at++]();
        clock.start();
    }
    Component.onCompleted: clock.start()
}
