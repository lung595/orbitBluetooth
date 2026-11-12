import QtQuick
import qs.Common
import "components/scene"
import "mock"

// Test of a device's signal on the scene (audit 2026-11): it glides to a new
// RSSI inside the scene's own loop, never through a QML animation (which,
// restarted on every RSSI update of a scan, kept the whole shell redrawing).
// A change wakes a settled scene, which settles again once the signal is
// there; with Reduce motion it is put there at once. Made-up device. Run with
// tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string address: "02:00:00:00:30:01"
    Device {
        id: dev
        address: h.address
        name: "Test Speaker"
        icon: "audio-speakers"
        paired: true
        bonded: true
        connected: false
        signalStrength: 40
    }
    FakeRoute {
        id: route
    }
    OrbitScene {
        id: scene
        anchors.fill: parent
        active: true
        autoScan: false
        previewDevices: [dev]
        audioRoute: route
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function body() {
        return scene.centre.bodyOf(h.address);
    }
    property bool settledSeen: false
    Timer {
        id: probe
        interval: 16
        repeat: true
        onTriggered: {
            if (!scene.settled)
                return;
            h.settledSeen = true;
            // The new RSSI lands on a scene really at rest
            if (h.armed) {
                h.armed = false;
                dev.signalStrength = 80;
                h.woke = !scene.settled;
            }
        }
    }
    property bool armed: false
    property bool woke: false
    // How many values the signal took on its way (offscreen, the loop may
    // run faster than a screen would, so time says little)
    property int changes: 0
    Connections {
        target: h.body()
        ignoreUnknownSignals: true
        function onSignalChanged() {
            h.changes++;
        }
    }

    readonly property var steps: [
        {
            "then": 3000,
            "run": () => {
                SettingsData.reduceMotion = true;
                probe.start();
            }
        },
        {
            "then": 3000,
            "run": () => {
                check("Reduce motion: the scene has settled", [h.settledSeen, !!body()], [true, true]);
                h.armed = true;
            }
        },
        {
            "then": 1500,
            "run": () => {
                check("a new RSSI wakes the settled scene", [h.armed, h.woke], [false, true]);
                check("Reduce motion: the signal is there at once", Math.round(body().signal * 100), 80);
                h.settledSeen = false;
            }
        },
        {
            "then": 2000,
            "run": () => {
                check("and the scene settles again", h.settledSeen, true);
                probe.stop();
                SettingsData.reduceMotion = false;
                h.changes = 0;
                dev.signalStrength = 20;
            }
        },
        {
            "then": 0,
            "run": () => {
                check("with motion it glides: many values on its way", h.changes > 5, true);
            }
        },
        {
            "then": 0,
            "run": () => {
                check("and arrives", Math.round(body().signal * 100), 20);
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
