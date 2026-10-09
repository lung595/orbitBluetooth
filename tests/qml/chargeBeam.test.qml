import QtQuick
import qs.Common
import "components/device"
import "components/scene"

// Test of the charging beam's styles: the dispatcher builds only the style
// chosen (and Filament for an unknown one, or one not drawn yet), switching is
// live, a beam that is hidden builds nothing, and with Reduce motion every
// style is a still frame that does not move with the clock.
// Run with tests/qml/run.sh.
Item {
    id: h
    width: 200
    height: 60

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function find(root, test) {
        if (test(root))
            return root;
        for (const c of root.children) {
            const hit = find(c, test);
            if (hit)
                return hit;
        }
        return null;
    }

    BeamLink {
        id: link
        width: 160
        height: 44
        startColor: "#42a5f5"
        endColor: "#5cf2c4"
    }

    readonly property var isPulse: c => c.capsuleLength !== undefined
    readonly property var isFilament: c => c.lengthPx !== undefined
    function built() {
        return [find(link, isPulse) !== null, find(link, isFilament) !== null];
    }
    // Where the capsules are (x of the three rectangles under the pulse item)
    function capsuleXs() {
        const p = find(link, isPulse);
        return p.children.filter(c => c.at !== undefined).map(c => Math.round(c.x * 100) / 100);
    }

    // A device and a scene as ChargeBeam reads them
    Item {
        id: world
    }
    QtObject {
        id: scene
        property string beamStyle: "filament"
        property bool awake: true
        property bool motion: true
        property bool cardOpen: false
        property real fxTime: 0
        property real coreSize: 40
        readonly property Item world: world
        readonly property var centre: ({
                "host": {
                    "x": 10,
                    "y": 10,
                    "scale": 1
                },
                "tetherless": a => a === "TETHERLESS"
            })
    }
    QtObject {
        id: body
        property string address: "AA:BB:CC:DD:EE:01"
        property bool charging: true
        property bool leaving: false
        property bool focused: false
        property real diameter: 60
        property real baseScale: 1
        readonly property var scene: scene
        readonly property var night: NightColors {}
    }
    ChargeBeam {
        id: flow
        body: body
        dist: 200
    }

    function run() {
        runScene();
        runLink();
    }

    // The beam of a charging device follows the setting and the IPC value at once
    function runScene() {
        const link = find(world, c => c.shown !== undefined);
        check("a charging device has a beam, Filament by default", [flow.visible, link?.shown], [true, "filament"]);
        check("the beam runs while seen, awake and moving", link.running, true);
        scene.beamStyle = "pulse";
        check("the scene's style reaches the beam at once", link.shown, "pulse");
        check("the beam's colours are the primary and the charge colour", [link.startColor.toString(), link.endColor.toString()], [body.night.primary.toString(), body.night.charging.toString()]);
        scene.motion = false;
        check("Reduce motion: the clock is not followed", link.running, false);
        scene.motion = true;
        scene.awake = false;
        check("asleep scene (locked, covered, screen off): not running", link.running, false);
        scene.awake = true;
        scene.beamStyle = "nonsense";
        check("an unknown style is Filament", link.shown, "filament");

        body.charging = false;
    }

    // After the 500 ms fade
    function runFaded() {
        check("not charging: the beam is hidden and builds nothing", [flow.visible, find(world, c => c.lengthPx !== undefined || c.capsuleLength !== undefined)], [false, null]);
        body.charging = true;
        body.address = "TETHERLESS";
    }
    function runTetherless() {
        check("a tetherless member never has a beam", [flow.visible, find(world, c => c.lengthPx !== undefined || c.capsuleLength !== undefined)], [false, null]);
        body.address = "AA:BB:CC:DD:EE:01";
    }

    function runLink() {
        check("the default is Filament, built alone", [link.shown, ...built()], ["filament", false, true]);

        link.style = "pulse";
        check("Pulse replaces Filament at once, Filament is gone", [link.shown, ...built()], ["pulse", true, false]);
        check("Pulse is three capsules", find(link, isPulse).children.filter(c => c.at !== undefined).length, 3);

        link.style = "filament";
        check("back to Filament", [link.shown, ...built()], ["filament", false, true]);

        for (const odd of ["gauge", "", "chain", "horizon"]) {
            link.style = odd;
            check("'" + odd + "' is drawn as Filament", [link.shown, ...built()], ["filament", false, true]);
        }

        // The colours reach the shader: from the host's to the device's
        const beam = find(link, isFilament);
        check("Filament shifts from the start colour to the end colour", [beam.color.toString(), beam.endColor.toString()], ["#42a5f5", "#5cf2c4"]);

        // Still frame: Reduce motion (not running) ignores the clock
        link.style = "pulse";
        link.running = false;
        link.time = 0;
        const still = capsuleXs();
        link.time = 7.3;
        check("Pulse at rest does not follow the clock", capsuleXs(), still);
        const w = 160 - 16;
        check("Pulse at rest: capsules at 1/6, 1/2 and 5/6 of the link", still, [1 / 6, 1 / 2, 5 / 6].map(a => Math.round(a * w * 100) / 100));
        link.running = true;
        link.time = 0.4;
        check("Pulse running: the capsules move", capsuleXs().join() !== still.join(), true);
        link.time = 0.4 + 1.6;
        link.offset = 0;
        const turn = capsuleXs();
        link.time = 0.4;
        check("Pulse: one period later the capsules are back", turn, capsuleXs());
        link.offset = 0;
        link.time = 0.4;
        const undelayed = capsuleXs();
        link.offset = 0.4;
        link.time = 0.8;
        check("a delayed beam is where the undelayed one was", capsuleXs(), undelayed);
        link.offset = 0;

        link.style = "filament";
        link.running = false;
        link.time = 0;
        const phase0 = find(link, isFilament).phase;
        link.time = 3.1;
        check("Filament at rest has phase 0 whatever the clock", [phase0, find(link, isFilament).phase], [0, 0]);
        link.running = true;
        check("Filament running follows the clock", find(link, isFilament).phase > 0, true);

        // A hidden beam builds nothing
        link.visible = false;
        check("hidden: no style is built", built(), [false, false]);
        link.visible = true;
        check("shown again: the style is back", built(), [false, true]);

        // The scene's clock is the only one: no animation in either style
        for (const s of ["pulse", "filament"]) {
            link.style = s;
            const animated = (function scan(item) {
                    return item.children.some(c => c.toString().indexOf("Animation") >= 0 || c.toString().indexOf("Animator") >= 0 || scan(c));
                })(link);
            check(s + ": no QML animation inside", animated, false);
        }
    }

    Timer {
        interval: 300
        running: true
        onTriggered: {
            h.run();
            fade.start();
        }
    }
    Timer {
        id: fade
        interval: 700
        property int step: 0
        repeat: true
        onTriggered: {
            if (step++ === 0) {
                h.runFaded();
                return;
            }
            stop();
            h.runTetherless();
            print(h.failures ? h.failures + " failure(s)" : "all passed");
            Qt.exit(h.failures ? 1 : 0);
        }
    }
    Timer {
        interval: 20000
        running: true
        onTriggered: {
            print("FAIL timed out: a step threw");
            Qt.exit(1);
        }
    }
}
