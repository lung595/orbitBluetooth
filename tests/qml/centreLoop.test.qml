import QtQuick
import qs.Common
import qs.Services
import "components/centre/Sun.js" as Sun
import "components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Test of the whole scene with a Listen together at the centre: the group
// lands (the source in the middle, the others on its orbit) and the scene's
// one loop stops by itself whenever nobody can see it move: with Reduce motion
// on, or while the session is locked; it runs while it is awake with motion on
// (the counter-proof), and the parts unload when the group ends (value 6).
// The solar system rides that loop: the sun rests with Reduce motion and turns
// with motion, the group stays in the middle and the devices outside it live
// around the sun, the source is as big as the core, and a new source grows
// into its role without a pop (F2).
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
    // The devices outside the group: how many, and how far they are on average from (x, y)
    function outside(x, y) {
        const c = scene.centre;
        let sum = 0, n = 0;
        for (let i = 0; i < c.bodies.count; i++) {
            const b = c.bodies.itemAt(i);
            if (!b || c.members.indexOf(b.address) >= 0)
                continue;
            sum += Math.hypot(b.px - x, b.py - y);
            n++;
        }
        return {
            "n": n,
            "mean": n ? sum / n : 0
        };
    }
    // The discs of the old and the new source across a swap, one sample per 16 ms
    property var oldSource: []
    property var newSource: []
    function sampled(values) {
        const jumps = values.slice(1).map((v, i) => v - values[i]);
        return {
            "total": values[values.length - 1] - values[0],
            "up": jumps.every(j => j >= -1e-9),
            "down": jumps.every(j => j <= 1e-9),
            "biggest": Math.max(...jumps.map(Math.abs))
        };
    }
    Timer {
        id: sampler
        interval: 16
        repeat: true
        onTriggered: {
            h.oldSource.push(scene.centre.bodyOf(h.headset).baseScale);
            h.newSource.push(scene.centre.bodyOf(h.two).baseScale);
        }
    }

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
                const host = scene.centre.host, near = h.outside(host.x, host.y), mid = h.outside(scene.cx, scene.cy);
                check("Reduce motion: the sun stays at its rest spot, the source is as big as the core", [scene.centre.sunPhase, scene.centre.bodyOf(h.headset).roleDiameter], [Sun.REST, scene.coreSize]);
                check("the devices outside the group live around the sun, not the middle (counter-proof: the middle)", [near.n > 0, near.mean < mid.mean], [true, true]);
                h.seen = scene.orbitTime;
            }
        },
        {
            "then": 100,
            "run": () => {
                // The source's click zone is its disc, as big as it is drawn, not the square around it
                const z = scene.centre.bodyOf(h.headset).pointer;
                const mid = z.width / 2;
                check("the disc answers the click, the corner of its square does not", [z.contains(Qt.point(mid, mid)), z.contains(Qt.point(mid + mid - 2, mid)), z.contains(Qt.point(3, 3))], [true, true, false]);
            }
        },
        {
            "then": 100,
            "run": () => {
                // A click on the ring lands where it is, even across the top from the level
                const ring = scene.world.ring.item;
                const at = v => [ring.width / 2 + Math.sin(v * 2 * Math.PI) * ring.radius, ring.height / 2 - Math.cos(v * 2 * Math.PI) * ring.radius];
                route.writeLevel(route.shared, 0.9);
                ring.press(...at(0.1));
                check("a click just past the top reads there, not at the far end", Math.round(route.shared.audio.volume * 100), 10);
                ring.press(...at(0.95));
                ring.drag(...at(0.05));
                check("held, crossing the top stops at the end", Math.round(route.shared.audio.volume * 100), 100);
                ring.drag(...at(0.9));
                check("and coming back follows the pointer", Math.round(route.shared.audio.volume * 100), 90);
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
                check("motion on: the sun turns, the group stays in the middle", [scene.centre.sunPhase > Sun.REST, h.at(h.headset)], [true, [scene.cx, scene.cy]]);
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
                // A member cannot be hidden: it would play on out of sight; it is told to leave first (value 10)
                const two = scene.centre.bodyOf(h.two);
                scene.hideBody(two);
                check("hiding a member says why, with the way to the guide", scene.note ? [scene.note.title.endsWith(" listens together"), scene.note.anchor] : null, [true, "hiding-devices-the-black-hole"]);
                check("and nothing moved: it is still there and in the group", [two.swallowing, route.sharing], [false, [h.headset, h.one, h.two]]);
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
            // Another member becomes the source: the discs grow and shrink to their roles.
            // Sampled while they are on their way (under the 0.8 s voyage): once there,
            // a copy's size follows the orbit's depth again, up and down
            "then": 400,
            "run": () => {
                h.oldSource = [scene.centre.bodyOf(h.headset).baseScale];
                h.newSource = [scene.centre.bodyOf(h.two).baseScale];
                sampler.start();
                route.sharing = [h.two, h.headset];
            }
        },
        {
            "then": 0,
            "run": () => {
                sampler.stop();
                check("a new source: the old one is now the second", [scene.centre.source, scene.centre.bodyOf(h.headset).role, scene.centre.bodyOf(h.two).role], [h.two, "copy", "source"]);
                const shrunk = h.sampled(h.oldSource), grown = h.sampled(h.newSource);
                check("the old source only shrinks across the swap", [shrunk.total < -0.1, shrunk.down], [true, true]);
                check("the new source only grows across the swap", [grown.total > 0.1, grown.up], [true, true]);
                check("and neither pops: no step is a big share of the change", [shrunk.biggest < -shrunk.total / 4, grown.biggest < grown.total / 4], [true, true]);
            }
        },
        {
            // With motion on the new source is carried to the middle by its spring, not put there
            "then": 1500,
            "run": () => {
                check("motion on: the new source is still on its way, off the middle", Math.hypot(...h.at(h.two).map((v, i) => v - [scene.cx, scene.cy][i])) > 3, true);
            }
        },
        {
            "then": 0,
            "run": () => {
                const [x, y] = h.at(h.two);
                check("motion on: the spring has brought the new source to the middle", Math.hypot(x - scene.cx, y - scene.cy) < 3, true);
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
