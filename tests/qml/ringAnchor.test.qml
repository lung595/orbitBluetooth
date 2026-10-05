import QtQuick
import qs.Common
import qs.Services
import "components/scene"
import "mock"
import "mock/Devices.js" as Devices

// Test of where the volume ring sits (D295): its middle and its size are the
// source disc's, as drawn, not where the group is meant to be. The disc
// follows its slot on a spring and grows to its role at the pace of the
// voyage, so a ring placed at the group's own position lagged behind it
// while the group moved (the voyage, then the sun carrying the group around
// the host's ring in Fedora's view). The real scene runs on its real timers
// and the gap between the ring's middle and the disc's is sampled every 16 ms.
// Run with tests/qml/run.sh.
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
    OrbitScene {
        id: scene
        anchors.fill: parent
        active: true
        autoScan: false
        previewDevices: Devices.list(false, 2)
        audioRoute: route
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // The worst gap (px) between the ring's middle and the source disc's, and
    // between the ring's size and the one the disc's size calls for (the ring
    // is 1.43 times the disc), over the samples of one phase
    property var worst: ({
            "move": 0,
            "size": 0,
            "samples": 0
        })
    function resetWorst() {
        worst = {
            "move": 0,
            "size": 0,
            "samples": 0
        };
    }
    function sample() {
        const ring = scene.world.ring.item;
        const disc = scene.centre.bodyOf(headset);
        if (!ring || !disc)
            return;
        const mid = ring.mapToItem(h, ring.width / 2, ring.height / 2);
        const drawn = disc.diameter * disc.baseScale;
        const call = scene.centre.sizes.ring / (scene.centre.sizes.source / 2);
        worst = {
            "move": Math.max(worst.move, Math.hypot(mid.x - disc.px, mid.y - disc.py)),
            "size": Math.max(worst.size, Math.abs(ring.radius * ring.scale - call * drawn / 2)),
            "samples": worst.samples + 1
        };
    }
    function fits(label) {
        check(label + ": the ring's middle is the disc's (within a pixel)", worst.move < 1, true);
        check(label + ": the ring's size follows the disc's", worst.size < 1, true);
        check(label + ": it was measured", worst.samples > 20, true);
        print("     (worst middle gap " + worst.move.toFixed(2) + " px, worst size gap " + worst.size.toFixed(2) + " px, " + worst.samples + " samples)");
    }
    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: h.sample()
    }

    // Each step runs, then waits `then` ms before the next
    readonly property var steps: [
        {
            "then": 1500,
            "run": () => {
                // The group forms: the camera travels, the disc follows its spring
                route.sharing = [h.headset, h.one, h.two];
            }
        },
        {
            "then": 1500,
            "run": () => {
                h.fits("voyage");
                h.resetWorst();
            }
        },
        {
            "then": 3500,
            "run": () => {
                h.fits("group view");
                h.resetWorst();
                // A click on the host: the group steps back onto the host's ring
                // and the sun carries it around
                scene.centre.recall();
            }
        },
        {
            "then": 0,
            "run": () => {
                h.fits("Fedora's view");
                check("the group is on the host's ring (it stepped back)", scene.centre.stage, 1);
            }
        }
    ]
    property int round: 0
    Timer {
        id: next
        interval: 600
        onTriggered: h.advance()
    }
    function advance() {
        if (round >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        const step = steps[round++];
        step.run();
        next.interval = Math.max(1, step.then);
        next.start();
    }
    Component.onCompleted: next.start()

    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 25000
        running: true
        onTriggered: {
            print("FAIL timed out: a step threw");
            Qt.exit(1);
        }
    }
}
