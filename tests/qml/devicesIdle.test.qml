import QtQuick
import qs.Common
import "components/scene"
import "mock"
import "mock/Devices.js" as Devices

// Test of the scene's slow device poll (audit 2026-11): every 1.5 s while
// someone looks, it reads the devices again; when nothing changed it does
// nothing, so a scene at rest stays at rest. A change still wakes it.
// Made-up devices. Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    FakeRoute {
        id: route
    }
    OrbitScene {
        id: scene
        anchors.fill: parent
        active: true
        autoScan: false
        previewDevices: Devices.list(false, 0)
        audioRoute: route
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // How many times the scene woke from rest since `watching` was set
    property bool watching: false
    property int wakes: 0
    Connections {
        target: scene
        function onSettledChanged() {
            if (h.watching && !scene.settled)
                h.wakes++;
        }
    }

    readonly property var steps: [
        {
            "then": 4000,
            "run": () => {
                SettingsData.reduceMotion = true;
            }
        },
        {
            "then": 4000,
            "run": () => {
                check("Reduce motion: the scene is at rest, the poll runs", [scene.settled, scene.awake], [true, true]);
                h.watching = true;
            }
        },
        {
            "then": 1000,
            "run": () => {
                check("nothing changed for 4 s: the poll never woke it", h.wakes, 0);
                // A device more: the next poll or the model's signal wakes it
                scene.previewDevices = Devices.list(false, 1);
            }
        },
        {
            "then": 0,
            "run": () => {
                check("a new device still wakes it", h.wakes > 0, true);
            }
        }
    ]
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
