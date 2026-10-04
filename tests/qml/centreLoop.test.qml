import QtQuick
import qs.Common
import qs.Services
import "components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Test of the whole scene with a Listen together at the centre: the group
// lands (the source in the middle, the others on its orbit) and the scene's
// one loop stops by itself whenever nobody can see it move: with Reduce motion
// on, or while the session is locked; it runs while it is awake with motion on
// (the counter-proof), and the parts unload when the group ends (value 6).
// The scene runs on its real timers, so each step waits a moment. Run with
// tests/qml/run.sh.
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
    function at(address) {
        const b = scene.centre.bodyOf(address);
        return b ? [Math.round(b.px), Math.round(b.py)] : null;
    }
    property real seen: 0

    // Each step runs, then waits `then` ms before the next
    readonly property var steps: [
        {
            "then": 1800,
            "run": () => {
                // Reduce motion: the group is put in place, and the loop stops
                SettingsData.reduceMotion = true;
                route.sharing = [h.headset, h.one, h.two];
            }
        },
        {
            "then": 400,
            "run": () => {
                check("Reduce motion: the group has landed", [scene.centre.grouping, scene.centre.shown], [1, true]);
                check("the source is in the middle", h.at(h.headset), [scene.cx, scene.cy]);
                check("the scene's loop has stopped", scene.settled, true);
                h.seen = scene.orbitTime;
            }
        },
        {
            "then": 800,
            "run": () => {
                check("and the orbit clock does not run", scene.orbitTime, h.seen);
                // Motion back on: the loop runs again (counter-proof)
                SettingsData.reduceMotion = false;
                scene.wake();
            }
        },
        {
            "then": 300,
            "run": () => {
                check("motion on: the loop runs, the orbit turns", [scene.settled, scene.orbitTime > h.seen], [false, true]);
            }
        },
        {
            "then": 300,
            "run": () => {
                // A device that is not connected, dragged onto the group, is told to connect first (value 10)
                const src = scene.centre.bodyOf(h.headset), mouse = scene.centre.bodyOf(h.mouse);
                scene.beginDrag(mouse, {
                    "x": mouse.px,
                    "y": mouse.py
                });
                scene.updateDrag({
                    "x": src.px,
                    "y": src.py
                });
                check("an unconnected device over the group is taken as a drop", scene.togetherDrop === src, true);
                scene.endDrag();
                check("released there, it is told to connect first", scene.note ? scene.note.title.endsWith(" is not connected") : null, true);
                scene.note = null;
            }
        },
        {
            "then": 300,
            "run": () => {
                // Pulled out of the group, a member leaves it but stays connected
                const one = scene.centre.bodyOf(h.one);
                scene.beginDrag(one, {
                    "x": one.px,
                    "y": one.py
                });
                scene.updateDrag({
                    "x": scene.cx + scene.rx * 1.4,
                    "y": scene.cy
                });
                check("pulled far from the group, the member is armed", one.armed, true);
                scene.endDrag();
                check("released there, it leaves the group", route.sharing, [h.headset, h.two]);
                check("and it is not disconnected", one.phase !== "disconnecting", true);
            }
        },
        {
            "then": 1500,
            "run": () => {
                // The session locks: nobody sees it
                SessionService.locked = true;
            }
        },
        {
            "then": 400,
            "run": () => {
                check("locked: the loop stops", scene.settled, true);
                h.seen = scene.orbitTime;
            }
        },
        {
            "then": 400,
            "run": () => {
                check("locked: the orbit clock does not run", scene.orbitTime, h.seen);
                SessionService.locked = false;
                scene.wake();
            }
        },
        {
            "then": 300,
            "run": () => {
                check("unlocked: it runs again", [scene.settled, scene.orbitTime > h.seen], [false, true]);
            }
        },
        {
            // The group ends: the camera goes back, then the parts unload
            "then": 1500,
            "run": () => {
                route.sharing = [];
            }
        },
        {
            "then": 0,
            "run": () => {
                check("the group ends: the parts unload", [scene.centre.shown, scene.centre.members], [false, []]);
                check("the host is back in the middle", [scene.centre.host.scale, scene.centre.hostAway], [1, false]);
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
