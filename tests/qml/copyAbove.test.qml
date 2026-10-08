import QtQuick
import qs.Common
import qs.Services
import "components/centre/Centre.js" as Centre
import "components/scene"
import "mock"
import "mock/State.js" as State
import "mock/Devices.js" as Devices

// Test of a copy that passes behind the source of a Listen together group: it
// is drawn over the source as a dashed outline (its disc gone), and it is the
// one that answers a press at its middle, instead of waiting for its turn round
// to the front.
// The orbit rests (Reduce motion) at a time chosen so that the copy sits at the
// far end of its orbit, right over the source. The press is routed as Qt does:
// to the highest stacking order whose zone holds the point. Run with
// tests/qml/run.sh.
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

    // What a press at a scene point reaches: the body whose zone holds it and
    // whose stacking order is the highest (the later one when they tie)
    function pressReaches(x, y) {
        return scene.world.bodyList().filter(b => b.pointer.enabled && b.pointer.contains(b.pointer.mapFromItem(scene.world, x, y))).reduce((top, b) => !top || b.z >= top.z ? b : top, null);
    }
    function wired(address) {
        return scene.world.wiredMembers.list().find(b => b.address === address) ?? null;
    }
    readonly property bool landed: scene.centre.grouping === 1 && !scene.centre.travelling

    readonly property var steps: [
        {
            "then": 200,
            "until": () => h.landed,
            "run": () => {
                SettingsData.reduceMotion = true;
                route.sharing = [h.headset, h.one, h.dac];
            }
        },
        {
            // The Bluetooth copy (the first to join) at the far end of its orbit
            "then": 500,
            "until": () => scene.world.wiredMembers.count === 1,
            "run": () => {
                scene.orbitTime = 21.875;
                scene.wake();
            }
        },
        {
            "then": 500,
            "run": () => {
                const src = scene.centre.bodyOf(h.headset), copy = scene.centre.bodyOf(h.one);
                const over = Math.hypot(copy.px - src.px, copy.py - src.py) < src.diameter * src.baseScale / 2;
                check("the Bluetooth copy is at the far end of its orbit, over the source's disc", [copy.depth < -0.9, over], [true, true]);
                check("it is drawn over the source", copy.z > src.z, true);
                check("a press at its middle reaches it, not the source", pressReaches(copy.px, copy.py) === copy, true);
                check("with the old stacking (far copies behind the source) the source got it (counter-proof)", src.z > scene.centre.groupZ + copy.depth, true);
                check("a press on the source's side, away from both copies, still reaches the source", pressReaches(src.px - src.diameter * src.baseScale * 0.4, src.py) === src, true);
                check("it is only a dashed outline there (its disc has gone), and the outline is shown", [copy.solid, copy.outline.active, copy.outline.item.visible, copy.outline.item.opacity], [0, true, true, 1]);
                check("the source itself is whole and has no outline", [src.solid, src.outline.active], [1, false]);
                check("the cables and beams stay under every member", [scene.world.beams.z < src.z, scene.world.beams.z < copy.z], [true, true]);
                // The wired copy, now at the near end: whole and in front
                const w = wired(h.dac);
                check("the wired copy, on the near side, is whole (no outline drawn) and over the source too", [w.depth > 0.9, w.solid, w.outline.item.visible, w.z > src.z], [true, 1, false, true]);
                // The orbit turns half way round: the wired copy goes behind the source
                scene.orbitTime = 9.375;
                scene.wake();
            }
        },
        {
            "then": 500,
            "run": () => {
                const src = scene.centre.bodyOf(h.headset), w = wired(h.dac);
                const over = Math.hypot(w.px - src.px, w.py - src.py) < src.diameter * src.baseScale / 2;
                check("the wired copy is at the far end of its orbit, over the source's disc", [w.depth < -0.9, over], [true, true]);
                check("it is drawn over the source as a dashed outline", [w.z > src.z, w.solid, w.outline.item.visible], [true, 0, true]);
                check("a press at its middle reaches it, not the source", pressReaches(w.px, w.py) === w, true);
                check("the cable stays under it", scene.world.beams.z < w.z, true);
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
