import QtQuick
import qs.Common
import "."

// Test of the real settings page (NAK-261): the ten pages load with no QML
// error (run.sh fails on any warning), the page opens on the Orbit category
// with its habit rows following the search filter: they show while browsing,
// and a search that matches another setting hides them. The other tests use
// stand-ins; this one loads OrbitBluetoothSettings.qml itself, so a page that
// refers to something that no longer exists cannot pass unseen. Run with
// tests/qml/run.sh.
Item {
    id: h
    width: 600
    height: 800

    OrbitBluetoothSettings {
        id: settings
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // The first item below `from` that `test` accepts, looking everywhere
    function find(from, test) {
        for (const item of from.children) {
            if (test(item))
                return item;
            const inside = find(item, test);
            if (inside)
                return inside;
        }
        return null;
    }
    function pill(key) {
        return find(settings, i => i.forKey === key);
    }
    readonly property var field: find(settings, i => i.focusField && i.view)
    // The "Learn my groups" row sits in the first child of the habit row
    readonly property var habits: find(settings, i => i.remembered !== undefined && i.owner)

    readonly property var steps: [
        {
            "then": 50,
            "run": () => {
                h.check("the search field is there", h.field !== null, true);
                h.check("so is the habit row, wired to its page", h.habits !== null, true);
                h.check("browsing shows the habit switch", h.habits.children[0].visible, true);
                h.field.view.query = "wired delay";
            }
        },
        {
            "then": 50,
            "run": () => {
                h.check("a search for another setting hides the habit switch", h.habits.children[0].visible, false);
                h.field.view.query = "learn my groups";
            }
        },
        {
            "then": 50,
            "run": () => {
                h.check("a search for it shows it", h.habits.children[0].visible, true);
                h.field.view.query = "";
                h.field.view.open("scanning", "");
            }
        },
        {
            "then": 50,
            "run": () => {
                h.check("the Scanning page shows the battery pill of the background scan", h.pill("offerScan").visible, true);
                h.check("the pill of the interval waits for the scan to be on", h.pill("offerEvery").visible, false);
                h.field.view.query = "wired delay";
            }
        },
        {
            "then": 50,
            "run": () => {
                h.check("a search for another setting hides the pill", h.pill("offerScan").visible, false);
                h.field.view.query = "";
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
    Component.onCompleted: Qt.callLater(next)
}
