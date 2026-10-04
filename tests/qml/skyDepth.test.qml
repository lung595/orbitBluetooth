import QtQuick
import qs.Common
import qs.Services
import "components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Test of the sky's depth of field while a Listen together has the centre (D294).
// DecorDepth on a stand-in sky: outside a group nothing exists (no copy, the
// source untouched); at the first sign of depth the blurred copy is made and
// kept as a texture that is never live; at full depth the live source is
// switched off in memory and its own look comes back after (counter-proof: a
// source with a look of its own); with Reduce motion there is no dissolve; a
// gesture that needs the live part brings it back. Then the real scene: the
// starfield stops twinkling behind the copy and is back when the group ends.
// The default offscreen backend draws no effects, so what is tested is the
// logic (what exists, what is live, what is drawn), not the pixels: those are
// checked by scripts/preview/depth.sh. Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    // A stand-in sky that has its own look (opacity 0.8), as a part of the real one might
    Rectangle {
        id: sky
        width: 300
        height: 200
        color: "navy"
        opacity: 0.8
    }
    DecorDepth {
        id: depthOf
        source: sky
    }
    // The same on a source that is not shown (no Bluetooth: no black hole)
    Rectangle {
        id: hidden
        width: 100
        height: 100
        visible: false
    }
    DecorDepth {
        id: hiddenDepth
        source: hidden
        depth: 1
    }

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

    // The scene's starfield: the one item that has `shootingStars`
    function find(item, prop) {
        for (const child of item.children) {
            if (prop in child)
                return child;
            const found = find(child, prop);
            if (found)
                return found;
        }
        return null;
    }
    // The loader that holds a DecorDepth's blurred copy
    function copyOf(decor) {
        return decor.children.find(c => "sourceComponent" in c);
    }
    // The ShaderEffectSource that keeps the blur
    function kept(decor) {
        const loader = copyOf(decor);
        return loader && loader.item ? find(loader.item, "scheduleUpdate") : null;
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    property var stars: null

    readonly property var steps: [
        {
            "then": 200,
            "run": () => {
                check("sharp: nothing exists, the source is untouched", [depthOf.copied, depthOf.frozen, sky.opacity], [false, false, 0.8]);
                // No Bluetooth, no black hole: its copy must not appear (the live part is not shown either)
                check("a source that is not shown has a copy that is not shown", h.copyOf(hiddenDepth).visible, false);
                check("and a shown source's copy is shown", h.copyOf(depthOf).visible, true);
                depthOf.depth = 0.3;
            }
        },
        {
            "then": 300,
            "run": () => {
                check("a little depth: the copy exists, not frozen, the source still drawn", [depthOf.copied, depthOf.frozen, sky.opacity], [true, false, 0.8]);
                const k = h.kept(depthOf);
                check("the copy is a texture that is never live (rendered once, then kept)", k ? k.live : null, false);
                check("and it follows the source's place and size", [depthOf.width, depthOf.height], [300, 200]);
                depthOf.depth = 1;
            }
        },
        {
            "then": 600,
            "run": () => {
                check("full depth, copy rendered: the live source is switched off (not drawn)", [depthOf.ready, depthOf.frozen, sky.opacity], [true, true, 0]);
                depthOf.hold = true;
            }
        },
        {
            "then": 600,
            "run": () => {
                check("a gesture needs the live part: it is back, the copy faded out", [depthOf.frozen, sky.opacity, depthOf.mix], [false, 0.8, 0]);
                depthOf.hold = false;
            }
        },
        {
            "then": 600,
            "run": () => {
                check("the gesture is over: the copy covers it again", [depthOf.frozen, sky.opacity], [true, 0]);
                depthOf.depth = 0.5;
            }
        },
        {
            "then": 100,
            "run": () => {
                check("leaving full depth: the source's own look is back (counter-proof: not forced to 1)", [depthOf.frozen, sky.opacity], [false, 0.8]);
                depthOf.depth = 0;
            }
        },
        {
            "then": 100,
            "run": () => {
                check("sharp again: the copy is gone, nothing is left behind", [depthOf.copied, depthOf.frozen, sky.opacity], [false, false, 0.8]);
                depthOf.motion = false;
                depthOf.depth = 0.4;
            }
        },
        {
            "then": 100,
            "run": () => {
                check("Reduce motion: under half way it is still sharp, no copy", [depthOf.shown, depthOf.copied], [0, false]);
                depthOf.depth = 0.6;
            }
        },
        {
            "then": 600,
            "run": () => {
                check("Reduce motion: past half way it is blurred at once, no dissolve", [depthOf.shown, depthOf.copied, depthOf.frozen, sky.opacity], [1, true, true, 0]);
                depthOf.depth = 0;
                depthOf.motion = true;
            }
        },
        {
            // The real scene: a group with Reduce motion off lands, the sky goes behind.
            // Each step waits after it runs, so the voyage is waited out before the checks
            "then": 2500,
            "run": () => {
                h.stars = h.find(scene, "shootingStars");
                check("no group: the starfield twinkles and is drawn", [!!h.stars, h.stars.animate, h.stars.opacity], [true, true, 1]);
                route.sharing = ["02:00:00:00:10:06", "02:00:00:00:20:01"];
            }
        },
        {
            "then": 2500,
            "run": () => {
                check("a group has the centre: the sky is at full depth", scene.centre.presence, 1);
                check("and the live starfield rests behind its copy: not drawn, not twinkling", [h.stars.opacity, h.stars.animate], [0, false]);
                route.sharing = [];
            }
        },
        {
            "then": 0,
            "run": () => {
                check("the group ended: the starfield is back, sharp and alive", [h.stars.opacity, h.stars.animate], [1, true]);
            }
        }
    ]
    property int step: 0
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 30000
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
