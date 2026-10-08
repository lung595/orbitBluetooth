import QtQuick
import qs.Common
import qs.Services
import "components/centre/Centre.js" as Centre
import "components/scene"
import "mock"
import "mock/State.js" as State
import "mock/Devices.js" as Devices

// Test of the wired outputs of a Listen together group, seen from the scene
// (D298): a rounded square among the planets with its cable to the source,
// and nothing at all while the group is only Bluetooth. The cable hangs loose
// and goes taut once, in 0.4 s, when its output joins (and at once with Reduce
// motion); the disc rests with Reduce motion and the scene's loop still stops
// by itself; a device dropped on it joins the group, the wheel over it sets
// its own level, its menu offers to leave, and it can be the source itself.
// The scene runs on its real timers: a step waits its time, then until what it
// started has happened. Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string two: "02:00:00:00:20:02"
    readonly property string mouse: "D4:1A:88:10:5B:77"
    readonly property string dac: "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo"
    readonly property string screen: "alsa_output.pci-0000_00_1f.3.hdmi-stereo"

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
    // What the right-click menu offers on a disc (the scene's own is private)
    OrbitMenu {
        id: menu
        scene: scene
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // The wired disc of an output, and the parts drawn under the planets
    function disc(address) {
        return scene.world.wiredMembers.list().find(b => b.address === address) ?? null;
    }
    function drawn() {
        const item = scene.world.beams.item, all = [];
        for (let i = 0; item && i < item.children.length; i++)
            all.push(item.children[i]);
        return all;
    }
    // The cables (one per wired member) and the beams (one per Bluetooth copy)
    function cables() {
        return drawn().filter(c => c.tension !== undefined);
    }
    function cable(address) {
        return cables().find(c => c.address === address) ?? null;
    }
    function beams() {
        return drawn().filter(c => c.dx !== undefined);
    }
    function at(item) {
        return item ? [Math.round(item.px), Math.round(item.py)] : null;
    }
    // The group has landed: the camera is there and nothing is on its way
    readonly property bool landed: scene.centre.grouping === 1 && !scene.centre.travelling

    // The cable of the output that joins, one sample per 16 ms
    property var samples: []
    Timer {
        id: sampler
        interval: 16
        repeat: true
        onTriggered: {
            const c = h.cable(h.dac);
            if (c)
                h.samples.push({
                    "t": Date.now(),
                    "tension": c.tension,
                    "drop": c.drop
                });
        }
    }

    // Whether the loop stopped at some point: the devices' slow poll wakes the
    // scene for one step every 1.5 s, so a single read could land on that step
    property bool settledSeen: false
    Timer {
        id: settleProbe
        interval: 16
        repeat: true
        onTriggered: {
            if (scene.settled)
                h.settledSeen = true;
        }
    }

    property var spot: null
    property real seen: 0

    // Each step runs, waits `then` ms, and then waits for `until` (when it has
    // one) before the next
    readonly property var steps: [
        {
            // A group of two Bluetooth devices: nothing wired exists (value 6)
            "then": 200,
            "until": () => h.landed,
            "run": () => {
                SettingsData.reduceMotion = false;
                check("no group: nothing wired is made, no beam", [scene.centre.wired.count, scene.world.wiredMembers.count, scene.world.beams.active], [0, 0, false]);
                route.sharing = [h.headset, h.one];
            }
        },
        {
            "then": 700,
            "until": () => h.cable(h.dac) && h.cable(h.dac).tension === 1,
            "run": () => {
                check("a Bluetooth group: one beam, no cable, no wired disc", [h.beams().length, h.cables().length, scene.world.wiredMembers.count], [1, 0, 0]);
                // An output joins the group that is already there: its cable hangs loose, then goes taut
                h.samples = [];
                sampler.start();
                route.sharing = [h.headset, h.one, h.dac];
            }
        },
        {
            "then": 400,
            "run": () => {
                sampler.stop();
                const w = h.disc(h.dac), c = h.cable(h.dac), src = scene.centre.bodyOf(h.headset);
                check("the output joins: one disc, one cable, and still one beam for the other copy", [scene.centre.wired.count, scene.world.wiredMembers.count, h.cables().length, h.beams().length], [1, 1, 1, 1]);
                check("the disc is the output's: a copy, USB, named from its description", w ? [w.address, w.role, w.kind, w.name, w.connected] : null, [h.dac, "copy", "usb", "Fictional Audio DAC", true]);
                const v = h.samples.map(s => s.tension), first = h.samples.find(s => s.tension === 1);
                check("its cable hangs loose when it joins, curved", [v[0] < 0.6, Math.max(...h.samples.map(s => s.drop)) > 0], [true, true]);
                check("then goes taut and stays: never loosens again", [v[v.length - 1], v.every((x, i) => i === 0 || x >= v[i - 1] - 1e-9)], [1, true]);
                check("in one go of about 0.4 s", first ? first.t - h.samples[0].t >= 250 && first.t - h.samples[0].t <= 800 : null, true);
                check("taut, it is a straight line from the source's middle to the disc's", [c.drop, Math.round(c.length)], [0, Math.round(Math.hypot(w.px - src.px, w.py - src.py))]);
                h.spot = [w.px, w.py];
                h.seen = scene.orbitTime;
            }
        },
        {
            "then": 100,
            "until": () => h.settledSeen,
            "run": () => {
                const w = h.disc(h.dac);
                check("motion on: the wired disc turns with the group's orbit", [scene.orbitTime > h.seen, Math.hypot(w.px - h.spot[0], w.py - h.spot[1]) > 0.5], [true, true]);
                // Reduce motion: the group rests, and the loop stops
                SettingsData.reduceMotion = true;
                settleProbe.start();
            }
        },
        {
            "then": 800,
            "run": () => {
                const w = h.disc(h.dac), src = scene.centre.bodyOf(h.headset), other = scene.centre.bodyOf(h.one);
                settleProbe.stop();
                check("Reduce motion: the scene's loop still stops with a wired member", h.settledSeen, true);
                check("the wired disc sits on the orbit like a copy, opposite the other one", [Math.abs(w.px + other.px - 2 * src.px) < 2, Math.abs(w.py + other.py - 2 * src.py) < 2], [true, true]);
                // A copy is smaller on the far side of the orbit: compared at the same depth
                check("it is drawn at the copies' size", Math.abs(w.diameter / Centre.depthSize(w.depth) - other.roleDiameter / Centre.depthSize(other.depth)) < 1, true);
                h.spot = at(w);
                h.seen = scene.orbitTime;
            }
        },
        {
            "then": 100,
            "until": () => h.disc(h.screen) && h.cable(h.screen),
            "run": () => {
                const w = h.disc(h.dac);
                check("Reduce motion: the wired disc rests and the orbit clock does not run", [at(w), scene.orbitTime], [h.spot, h.seen]);
                // A second output joins with Reduce motion: whole at once, its cable taut
                route.sharing = [h.headset, h.one, h.dac, h.screen];
            }
        },
        {
            "then": 0,
            "run": () => {
                const w = h.disc(h.screen), c = h.cable(h.screen);
                check("Reduce motion: the new disc is whole at once, its cable taut and straight", [w.kind, w.arrive, c.tension, c.drop], ["hdmi", 1, 1, 0]);
                check("the wired discs are not on top of each other", Math.hypot(w.px - h.disc(h.dac).px, w.py - h.disc(h.dac).py) > w.diameter, true);
            }
        },
        {
            // A rounded square, not a disc: its corners answer, a round body's do not
            "then": 100,
            "run": () => {
                const w = h.disc(h.dac), z = w.pointer, round = scene.centre.bodyOf(h.one).pointer;
                const corner = (area, k) => area.contains(Qt.point(area.width / 2 * (1 + k), area.width / 2 * (1 + k)));
                check("the wired disc's zone is a rounded square: its middle and its shoulder answer, its far corner does not", [corner(z, 0), corner(z, 0.8), corner(z, 0.97)], [true, true, false]);
                check("a Bluetooth body's is a disc: the same shoulder does not answer (counter-proof)", [corner(round, 0), corner(round, 0.8)], [true, false]);
                check("the group's own search finds the wired disc on its shape, and nothing far from it", [scene.world.wiredMembers.at(w.px, w.py) === w, scene.world.wiredMembers.at(w.px + w.diameter, w.py + w.diameter) === null, scene.world.bodyAt(-500, -500)], [true, true, null]);
                check("the scene finds a body under the disc's middle, the host core must not take that click", !!scene.world.bodyAt(w.px, w.py), true);
            }
        },
        {
            // The cable follows the disc while it is carried out of the group, and goes back to its place when it is let go
            "then": 100,
            "run": () => {
                const w = h.disc(h.dac), c = h.cable(h.dac), home = [Math.round(w.px), Math.round(w.py)];
                scene.beginDrag(w, {
                    "x": w.px,
                    "y": w.py
                });
                scene.updateDrag({
                    "x": w.px - 120,
                    "y": w.py + 90
                });
                check("the cable's far end is where the carried disc is, not where it was", [Math.round(c.end.x), Math.round(c.end.y), Math.round(w.px), Math.round(w.py)], [home[0] - 120, home[1] + 90, home[0] - 120, home[1] + 90]);
                scene.updateDrag({
                    "x": w.px + 40,
                    "y": w.py - 30
                });
                check("and it keeps following the pointer", [Math.round(c.end.x), Math.round(c.end.y)], [home[0] - 80, home[1] + 60]);
                scene.dragBody = null;
                w.dragging = false;
                w.armed = false;
                scene.holeFeed = 0;
                check("let go, the cable is back on the disc's place (counter-proof)", [Math.round(c.end.x), Math.round(c.end.y)], home);
            }
        },
        {
            // A device carried over the wired disc is taken as a drop on it
            "then": 300,
            "run": () => {
                const w = h.disc(h.dac), mouse = scene.centre.bodyOf(h.mouse), two = scene.centre.bodyOf(h.two);
                scene.beginDrag(mouse, {
                    "x": mouse.px,
                    "y": mouse.py
                });
                scene.updateDrag({
                    "x": w.px,
                    "y": w.py
                });
                check("a device that is not connected, carried over a wired member, is taken as a drop on it", scene.togetherDrop === w, true);
                scene.endDrag();
                check("released there, it is told to connect first (never silence)", scene.note ? scene.note.title.endsWith(" is not connected") : null, true);
                scene.note = null;
                // A connected device: what the drop asks (OrbitDrag.end), the invitation and the join
                check("a connected device is ready to join through it, and the invitation shows on it", [scene.together.ready(two, w), scene.together.candidates(two).some(o => o === w)], [true, true]);
                scene.together.drop(two, w);
                check("dropped on it, the device joins the group", route.sharing, [h.headset, h.one, h.dac, h.screen, h.two]);
            }
        },
        {
            // The wheel over a wired member sets its own level, and nothing else moves
            "then": 100,
            "run": () => {
                const before = route.shared.audio.volume;
                check("a wired member has its own level, read from its output", Math.round(scene.centre.volume.ownLevel(h.dac) * 100), 40);
                scene.centre.volume.turn(h.dac, 1);
                check("the wheel over it moves its own level one step up", Math.round(route.usbDac.audio.volume * 100), 45);
                check("and the group's general level does not move (counter-proof)", route.shared.audio.volume, before);
            }
        },
        {
            // Its menu: Disconnect (it leaves the group and stays plugged in), never a Bluetooth entry; leaving removes the disc and its cable
            "then": 300,
            "until": () => scene.centre.wired.count === 1 && scene.world.wiredMembers.count === 1 && h.cables().length === 1,
            "run": () => {
                const w = h.disc(h.dac);
                scene.openMenu(w, Qt.point(60, 60));
                check("a press on the disc opens its menu", scene.menuOpen, true);
                scene.dismiss();
                menu.popup(w, Qt.point(60, 60));
                const ids = menu.entries.map(e => e.id);
                check("it offers to disconnect (leave the group) and nothing else: no Hide (a member only explains), nothing for a Bluetooth device", [menu.entries.map(e => e.label), ids.some(i => ["connect", "disconnect", "cancel", "forget", "separate", "group", "hide"].indexOf(i) >= 0)], [["Disconnect"], false]);
                menu.choose("leave");
                check("Disconnect takes the output out of the group, the others keep listening", route.sharing, [h.headset, h.one, h.screen, h.two]);
            }
        },
        {
            "then": 100,
            "until": () => {
                const w = h.disc(h.screen);
                return !!w && w.role === "source" && Math.round(w.px) === scene.cx && h.beams().length === 3;
            },
            "run": () => {
                check("its disc and its cable are gone, the other output's stay", [scene.centre.wired.count, scene.world.wiredMembers.count, h.cables().map(c => c.address)], [1, 1, [h.screen]]);
                // The output is the source: it takes the middle, as big as the core
                route.sharing = [h.screen, h.headset, h.one, h.two];
            }
        },
        {
            "then": 0,
            "until": () => !scene.centre.shown,
            "run": () => {
                const w = h.disc(h.screen), c = h.cable(h.screen), rays = h.beams();
                check("a wired source: the disc is the centre of the group, as big as the core", [w.role, at(w), w.diameter], ["source", [scene.cx, scene.cy], scene.coreSize]);
                check("it has no cable to itself", [c.linked, c.visible], [false, false]);
                check("the beams of the Bluetooth copies start from it", [rays.length, rays.every(r => Math.round(r.x) === scene.cx && Math.round(r.y) === scene.cy)], [3, true]);
                const general = route.shared.audio.volume;
                scene.centre.volume.turn(h.screen, 1);
                check("the wheel over a source is the group's general level: its own output's is left alone", [route.shared.audio.volume > general, Math.round(route.screen.audio.volume * 100)], [true, 70]);
                // The group ends: the camera goes back, then every wired part unloads
                route.sharing = [];
            }
        },
        {
            "then": 0,
            "run": () => {
                check("the group ends: no wired disc, no cable, the beams unload", [scene.centre.wired.count, scene.world.wiredMembers.count, scene.world.beams.active], [0, 0, false]);
            }
        }
    ]
    property int step: 0
    property int waited: 0
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 90000
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
