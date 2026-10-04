import QtQuick
import qs.Common
import qs.Services
import "components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Test of the invitation to listen together: carrying a connected audio
// device shows it on the devices it could join, only while it is still held
// to the ring, solid once the pointer is over one; carrying a device that is
// not connected shows nothing, and nothing is created once it is let go
// (value 6). The scene runs on its real timers. Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string two: "02:00:00:00:20:02"
    readonly property string mouse: "D4:1A:88:10:5B:77"

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
    function body(address) {
        return scene.world.bodyList().find(b => b.address === address);
    }
    readonly property var invitation: scene.world.invitation

    readonly property var steps: [
        {
            "then": 1500,
            "run": () => {
                check("at rest nothing is created", h.invitation.item, null);
            }
        },
        {
            "then": 300,
            "run": () => {
                // A connected device, carried but still held to the ring
                const b = h.body(h.headset);
                scene.beginDrag(b, {
                    "x": b.px,
                    "y": b.py
                });
                scene.updateDrag({
                    "x": b.px + 3,
                    "y": b.py
                });
                check("carried, it is invited to the two others", h.invitation.item ? h.invitation.item.targets.map(o => o.address).sort() : null, [h.one, h.two]);
                check("the invitation shows", h.invitation.item ? h.invitation.item.showing : null, true);
            }
        },
        {
            "then": 100,
            "run": () => {
                // Over one of them: the thread is whole
                const o = h.body(h.one);
                scene.updateDrag({
                    "x": o.px,
                    "y": o.py
                });
                check("over a device it could join, the thread is whole", [scene.togetherDrop === o, h.invitation.item.locked], [true, true]);
            }
        },
        {
            "then": 100,
            "run": () => {
                // Torn off to disconnect: the invitation is not what it is about
                scene.updateDrag({
                    "x": scene.cx + scene.rx * 1.4,
                    "y": scene.cy
                });
                check("torn off, the invitation hides", h.invitation.item.showing, false);
                const o = h.body(h.two);
                scene.updateDrag({
                    "x": o.px,
                    "y": o.py
                });
                scene.endDrag();
                check("let go over a device, the group starts", route.sharing, [h.headset, h.two]);
            }
        },
        {
            "then": 200,
            "run": () => {
                check("let go, nothing is left of the invitation", h.invitation.item, null);
                route.sharing = [];
            }
        },
        {
            "then": 600,
            "run": () => {
                // A device that is not connected has nothing to be invited to
                const b = h.body(h.mouse);
                scene.beginDrag(b, {
                    "x": b.px,
                    "y": b.py
                });
                scene.updateDrag({
                    "x": b.px + 3,
                    "y": b.py
                });
                check("a device that is not connected is not invited", h.invitation.item, null);
                scene.endDrag();
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
        PluginService.globalVars = State.globals("orbit", Date.now());
        Qt.callLater(next);
    }
}
