import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services
import "components/centre/Centre.js" as Centre
import "components/scene"
import "mock"
import "mock/State.js" as State
import "mock/Devices.js" as Devices

// Test of the copies' orbit in a Listen together group (D349): it is 40 % wider
// than a tight ring while the group has the centre and a tight ring once the
// group has stepped back onto the host's ring (and wide again when it returns),
// the copies sit on it, and a light dashed ellipse draws the path they follow:
// its far half behind the source, its near half in front of it and under every
// copy, carried and scaled with the group, and created only while there is a
// group. The copies' dashed outline at the horizon is checked here too (half
// way between whole and an outline). The orbit rests (Reduce motion) at the
// times chosen. Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string dac: "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo"

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
    // Within half a pixel (or a thousandth)
    function near(a, b, tol = 0.5) {
        return Math.abs(a - b) <= tol;
    }
    function wired(address) {
        return scene.world.wiredMembers.list().find(b => b.address === address) ?? null;
    }
    readonly property bool landed: scene.centre.grouping === 1 && !scene.centre.travelling
    // Every width the trajectory takes while the group steps back: it is laid
    // out again with the orbit, so none may be missed or jump
    property var widths: []
    Connections {
        target: scene.world.farOrbit.item?.ellipse ?? null
        ignoreUnknownSignals: true
        function onWidthChanged() {
            h.widths.push(target.width);
        }
    }

    readonly property var steps: [
        {
            "then": 200,
            "until": () => h.landed,
            "run": () => {
                check("no group, no trajectory: nothing is created before it is needed", [scene.world.farOrbit.active, scene.world.nearOrbit.active], [false, false]);
                check("a device outside any group has no outline either", scene.centre.bodyOf(h.one).outline.active, false);
                SettingsData.reduceMotion = true;
                route.sharing = [h.headset, h.one, h.dac];
            }
        },
        {
            // The two copies on the horizon, one each side of the source
            "then": 500,
            "until": () => scene.world.wiredMembers.count === 1,
            "run": () => {
                scene.orbitTime = 3.125;
                scene.wake();
            }
        },
        {
            "then": 500,
            "run": () => {
                const c = scene.centre, z = c.sizes, src = c.bodyOf(h.headset), copy = c.bodyOf(h.one), w = wired(h.dac);
                const R = z.radius;
                check("the orbit is 40 % wider than a tight ring (the ring, a gap, half a copy)", [Centre.ORBIT_SPREAD, near(R, Centre.ORBIT_SPREAD * (z.ring + 12 + z.copy / 2), 0.001)], [1.4, true]);
                check("a copy sits on that orbit: on the horizon it is a radius from the source, level with it", [near(copy.px - src.px, R), near(copy.py, src.py)], [true, true]);
                check("while the group has the centre the copies orbit at 1.4 times the tight radius, from the source", [Centre.spreadAt(c.stage), near(copy.px - src.px, Centre.ORBIT_SPREAD * Centre.sizes(scene, 1).radius)], [Centre.ORBIT_SPREAD, true]);
                check("the wired copy is on the other side of it, as far", [near(src.px - w.px, R), near(w.py, src.py)], [true, true]);
                check("the orbit fits the scene: the farthest copy is inside its width", [copy.px + z.copy / 2 < scene.width, w.px - z.copy / 2 > 0], [true, true]);
                check("on the horizon a copy is half way between whole and its outline", [near(copy.solid, 0.5, 0.001), near(w.solid, 0.5, 0.001), near(copy.outline.item.opacity, 0.5, 0.001), near(w.outline.item.opacity, 0.5, 0.001)], [true, true, true, true]);

                const far = scene.world.farOrbit, nearHalf = scene.world.nearOrbit;
                check("both halves of the trajectory exist now there is a group", [far.active, nearHalf.active], [true, true]);
                const e = far.item.ellipse;
                check("the ellipse is centred on the group, as wide as the copies' orbit and as tall as its tilt says", [near(e.x + e.width / 2, c.group.x), near(e.y + e.height / 2, c.group.y), near(e.width, 2 * (R + 1)), near(e.height, 2 * (R * Centre.TILT + 1))], [true, true, true, true]);
                check("the near half is the same ellipse", [nearHalf.item.ellipse.x, nearHalf.item.ellipse.y, nearHalf.item.ellipse.width], [e.x, e.y, e.width]);
                check("it is dashed and light, the far half paler than the near one", [far.item.trail.strokeStyle === ShapePath.DashLine, nearHalf.item.trail.strokeStyle === ShapePath.DashLine, far.item.trail.strokeColor.a < nearHalf.item.trail.strokeColor.a, nearHalf.item.trail.strokeColor.a < 0.3], [true, true, true, true]);
                check("the far half is behind the source and the near half in front of it", [far.z < src.z, nearHalf.z > src.z], [true, true]);
                // Angles run clockwise from 3 o'clock on screen: 180..360 is the top half
                check("the far half is the upper arc and the near half the lower one", [far.item.arc.startAngle, far.item.arc.sweepAngle, nearHalf.item.arc.startAngle, nearHalf.item.arc.sweepAngle], [180, 180, 0, 180]);
                check("it is as strong as the group is there", far.item.opacity, c.presence);
                // Where the copy and the wired one are now: one at the far end, one at the near end
                scene.orbitTime = 21.875;
                scene.wake();
            }
        },
        {
            "then": 500,
            "run": () => {
                const c = scene.centre, src = c.bodyOf(h.headset), copy = c.bodyOf(h.one), w = wired(h.dac);
                const nearHalf = scene.world.nearOrbit;
                check("a copy at the far end is an outline, the other at the near end whole", [copy.depth < -0.9, copy.solid, w.depth > 0.9, w.solid], [true, 0, true, 1]);
                check("the far end is above the source and the near end below it: where the two arcs are", [copy.py < src.py - 1, w.py > src.py + 1], [true, true]);
                check("the near half stays under every copy, even the farthest one (counter-proof: over it a copy would be drawn under the line)", [nearHalf.z < copy.z, nearHalf.z < w.z, nearHalf.z > src.z], [true, true, true]);
                // The group steps back onto this computer's ring: the trajectory goes with it, smaller
                c.recall();
            }
        },
        {
            "then": 300,
            "until": () => scene.centre.stage === 1 && !scene.centre.travelling,
            "run": () => {
                const c = scene.centre, e = scene.world.farOrbit.item.ellipse;
                check("stepped back, the group is smaller and the trajectory follows it: its centre and its scale", [c.group.scale < 1, near(e.x + e.width / 2, c.group.x), near(e.y + e.height / 2, c.group.y), near(e.scale, c.group.scale, 0.001)], [true, true, true, true]);
                // The copies back on the horizon, to measure the orbit there
                scene.orbitTime = 3.125;
                scene.wake();
            }
        },
        {
            "then": 500,
            "run": () => {
                const c = scene.centre, z = c.sizes, src = c.bodyOf(h.headset), copy = c.bodyOf(h.one), w = wired(h.dac), e = scene.world.farOrbit.item.ellipse;
                const tight = Centre.sizes(scene, 1).radius, k = c.group.scale;
                check("stepped back, the orbit is the tight ring again, not the wide one", [Centre.spreadAt(c.stage), near(z.radius, tight, 0.001)], [1, true]);
                check("the copies hug the source as they did before: a tight radius at the group's size, each side", [near(copy.px - src.px, tight * k), near(src.px - w.px, tight * k), near(copy.py, src.py)], [true, true, true]);
                check("the trajectory is that tight ring: its width, once scaled with the group", [near(e.width * e.scale, 2 * (tight + 1) * k)], [true]);
                check("no copy overlaps the volume ring: the nearest edge of a copy is clear of it", [copy.px - src.px - copy.diameter * copy.baseScale / 2 >= z.ring * k - 0.5, src.px - w.px - w.diameter * w.baseScale / 2 >= z.ring * k - 0.5], [true, true]);
                // It left the wide orbit by a smooth way: it only narrowed, from the wide width to the tight one
                const wide = 2 * (Centre.ORBIT_SPREAD * tight + 1), seen = h.widths, range = wide - 2 * (tight + 1);
                check("the trajectory went through the sizes in between, narrowing, none missed (no step over a third of the way)", [seen.length > 4, seen.every((v, i) => i === 0 || v <= seen[i - 1]), near(seen[0], wide, 12), near(seen[seen.length - 1], 2 * (tight + 1), 0.001), seen.every((v, i) => i === 0 || seen[i - 1] - v < range / 3)], [true, true, true, true, true]);
                h.widths = [];
                c.release();
            }
        },
        {
            "then": 300,
            "until": () => scene.centre.stage === 0 && !scene.centre.travelling,
            "run": () => {
                scene.orbitTime = 3.125;
                scene.wake();
            }
        },
        {
            "then": 500,
            "run": () => {
                const c = scene.centre, z = c.sizes, src = c.bodyOf(h.headset), copy = c.bodyOf(h.one), w = wired(h.dac), e = scene.world.farOrbit.item.ellipse;
                const tight = Centre.sizes(scene, 1).radius;
                check("released, the group has the centre back and the copies orbit wide again: 1.4 times the tight radius, each side", [Centre.spreadAt(c.stage), near(copy.px - src.px, Centre.ORBIT_SPREAD * tight), near(src.px - w.px, Centre.ORBIT_SPREAD * tight)], [Centre.ORBIT_SPREAD, true, true]);
                check("the trajectory is wide again with them, at the group's full size", [near(e.width, 2 * (Centre.ORBIT_SPREAD * tight + 1)), near(e.scale, 1, 0.001)], [true, true]);
                route.sharing = [];
            }
        },
        {
            "then": 200,
            "until": () => !scene.centre.shown,
            "run": () => {
                check("the group is gone: the trajectory is gone with it", [scene.world.farOrbit.active, scene.world.nearOrbit.active], [false, false]);
            }
        }
    ]

    property int step: 0
    property int waited: 0
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 60000
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
        const prev = step > 0 ? steps[step - 1] : null;
        // What the last step started has not happened yet: look again soon, for 20 s at most
        if (prev && prev.until && !prev.until() && waited < 20000) {
            waited += 50;
            clock.interval = 50;
            clock.start();
            return;
        }
        waited = 0;
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
