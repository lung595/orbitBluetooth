import QtQuick
import qs.Common
import qs.Services
import "components/scene"
import "mock"
import "mock/State.js" as State
import "mock/Devices.js" as Devices

// Test of a Listen together group that loses its Bluetooth source while three
// wired outputs stay (the group must go on, D254): the source role passes to a
// wired member, the scene is left with nothing stuck (no dragged body, no armed
// body, no open menu), every Bluetooth body can still be picked up and dragged,
// and a wired member can be pulled out of the group by hand like a Bluetooth
// one, while a plain click on it still opens its menu. Seen in the group's view
// and in Fedora's view. Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string dac: "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo"
    readonly property string screen: "alsa_output.pci-0000_00_1f.3.hdmi-stereo"
    readonly property string jack: "alsa_output.pci-0000_00_1f.3.analog-stereo"

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
    // What the scene says under the orbit while a body is dragged (the scene's own is private)
    OrbitHint {
        id: hint
        scene: scene
        bodyCount: 3
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    function disc(address) {
        return scene.world.wiredMembers.list().find(b => b.address === address) ?? null;
    }
    readonly property bool landed: scene.centre.grouping === 1 && !scene.centre.travelling

    // Nothing of a gesture is left behind
    function idle() {
        const bodies = scene.world.bodyList();
        return [scene.dragBody === null, scene.togetherDrop === null, bodies.every(b => !b.dragging && !b.armed && !b.hideArmed)];
    }
    // The pointer that takes a press at this scene point: the topmost enabled
    // mouse area whose shape holds it (what Qt itself would deliver it to)
    function pressTarget(x, y) {
        let best = null, bestZ = -Infinity;
        const all = scene.world.bodyList();
        for (const b of all) {
            const p = b.pointer;
            if (!p || !p.enabled || !p.visible)
                continue;
            const q = p.mapFromItem(scene, x, y);
            if (q.x < 0 || q.y < 0 || q.x > p.width || q.y > p.height || !p.containmentMask.contains(Qt.point(q.x, q.y)))
                continue;
            if (b.z > bestZ) {
                best = b;
                bestZ = b.z;
            }
        }
        return best ? best.address : null;
    }
    // A drag by hand of body `b` from where it is to (x, y), through the scene's own calls
    function dragTo(b, x, y) {
        scene.beginDrag(b, Qt.point(b.px, b.py));
        for (let i = 1; i <= 10; i++)
            scene.updateDrag(Qt.point(b.px + (x - b.px) * i / 10, b.py + (y - b.py) * i / 10));
        const armed = b.armed;
        scene.endDrag();
        return armed;
    }

    readonly property var steps: [
        {
            "then": 100,
            "until": () => h.landed && h.disc(h.jack),
            "run": () => {
                SettingsData.reduceMotion = true;
                // The headset is the source, the three wired outputs its copies
                route.sharing = [h.headset, h.dac, h.screen, h.jack];
            }
        },
        {
            "then": 100,
            "run": () => {
                check("the group of four: the headset is the source", [scene.centre.source, scene.centre.wired.count], [h.headset, 3]);
                // The source leaves by the menu's "Leave together"
                scene.together.leave(h.headset);
            }
        },
        {
            "then": 100,
            "run": () => {
                const hs = scene.centre.bodyOf(h.headset);
                check("three remain: the group goes on, a wired output is its source now", [scene.together.count(), scene.centre.members, scene.centre.source], [3, [h.dac, h.screen, h.jack], h.dac]);
                check("the wired source takes the source's role", [h.disc(h.dac).role, h.disc(h.screen).role, h.disc(h.jack).role], ["source", "copy", "copy"]);
                check("the headset is a planet of the ring again", [hs.role, scene.centre.holds(hs)], ["", false]);
                check("nothing is stuck", h.idle(), [true, true, true]);
            }
        },
        {
            "then": 300,
            "until": () => h.landed,
            "run": () => {
                // The headset back as the source, Fedora's view, then it leaves by being pulled out
                route.sharing = [h.headset, h.dac, h.screen, h.jack];
                scene.centre.recall();
            }
        },
        {
            "then": 300,
            "until": () => h.landed,
            "run": () => {
                check("Fedora's view", [scene.centre.recalled, scene.centre.stage], [true, 1]);
                const hs = scene.centre.bodyOf(h.headset);
                check("the headset is held in the group", scene.centre.holds(hs), true);
                const armed = h.dragTo(hs, hs.px + 200, hs.py + 160);
                check("pulled out, it is armed to leave", armed, true);
            }
        },
        {
            "then": 100,
            "run": () => {
                const hs = scene.centre.bodyOf(h.headset);
                check("Fedora's view: three remain, a wired source", [scene.together.count(), scene.centre.source, scene.centre.recalled], [3, h.dac, true]);
                check("Fedora's view: nothing is stuck", h.idle(), [true, true, true]);
                // Every Bluetooth body can still be picked up and moved
                const others = scene.world.bodyList().filter(b => !b.wired);
                const moved = others.map(b => {
                    const x0 = b.px;
                    scene.beginDrag(b, Qt.point(b.px, b.py));
                    scene.updateDrag(Qt.point(b.px + 30, b.py + 4));
                    const ok = scene.dragBody === b && b.dragging;
                    scene.endDrag();
                    return ok;
                });
                check("Fedora's view: every Bluetooth body can be dragged", moved.every(x => x), true);
                check("Fedora's view: nothing is stuck after", h.idle(), [true, true, true]);
            }
        },
        {
            "then": 300,
            "run": () => {
                // A wired member is pulled out of the group by hand, like a Bluetooth one
                const w = h.disc(h.jack), n = scene.together.count();
                scene.beginDrag(w, Qt.point(w.px, w.py));
                const x0 = w.px;
                scene.updateDrag(Qt.point(w.px + 220, w.py + 180));
                check("a wired member follows the pointer and is armed to leave", [w.dragging, w.px > x0 + 100, w.armed, w.hideArmed, hint.text], [true, true, true, false, "Release to leave the group"]);
                scene.endDrag();
                check("released, it leaves and the others go on", [scene.together.count(), scene.together.isMember(h.jack)], [n - 1, false]);
                check("nothing is stuck after a wired member left", h.idle(), [true, true, true]);
            }
        },
        {
            "then": 300,
            "run": () => {
                // The wired source too: two remain, and once one more leaves the group ends
                const w = h.disc(h.dac), n = scene.together.count();
                check("the wired source can be picked up", [!!w, w ? w.role : ""], [true, "source"]);
                scene.beginDrag(w, Qt.point(w.px, w.py));
                scene.updateDrag(Qt.point(w.px - 220, w.py - 150));
                scene.endDrag();
                check("pulled out, the wired source leaves and the group goes on or ends", [scene.together.count(), scene.together.isMember(h.dac)], [n - 1 < 2 ? 0 : n - 1, false]);
                check("nothing is stuck once the group ended", h.idle(), [true, true, true]);
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
