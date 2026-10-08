import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import "components/scene"
import "components/centre/Perspective.js" as Perspective
import "components/centre/Sun.js" as Sun
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Test of hiding from the group chooser: every row has an eye (under the pointer
// or the keys) that hides the output, a wired one as well as a Bluetooth one, in
// the store the black hole's counter and card read; a row can be carried to the
// black hole, which lights up and shows an eye, and is hidden when let go
// there (and not when let go elsewhere); the hidden ones wait in a Hidden
// section, folded to begin with and gone with the last one, each with an eye
// that brings it back; a member of the group is not hidden: the note says why;
// and the hole is drawn as big as its depth says in the profile view, smaller
// while a group has the centre (it shrinks with the host's system), as it was
// in the scene's own view. Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string two: "02:00:00:00:20:02"
    readonly property string usb: "alsa_output.usb-Maker_Interface-00.analog-stereo"
    readonly property string hdmi: "alsa_output.pci-0000_01_00.1.hdmi-stereo"

    // What `pactl --format=json list sinks` says on the made-up machine: an audio interface and a monitor
    readonly property string listing: JSON.stringify([
        {
            "name": h.usb,
            "description": "Interface Stereo",
            "active_port": "analog-output",
            "ports": [
                {
                    "name": "analog-output",
                    "availability": "availability unknown"
                }
            ],
            "properties": {
                "device.bus": "usb"
            }
        },
        {
            "name": h.hdmi,
            "description": "Desk Monitor",
            "active_port": "hdmi-output-0",
            "ports": [
                {
                    "name": "hdmi-output-0",
                    "availability": "available"
                }
            ],
            "properties": {
                "device.bus": "pci"
            }
        }
    ])

    FakeRoute {
        id: route
        wired: [h.usb, h.hdmi]
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
    function all(root, pred, found) {
        const out = found || [];
        for (let i = 0; i < root.children.length; i++) {
            if (pred(root.children[i]))
                out.push(root.children[i]);
            all(root.children[i], pred, out);
        }
        return out;
    }
    function menu() {
        return all(scene, c => c.entries !== undefined && c.choosing !== undefined)[0];
    }
    function chooser() {
        return all(scene, c => c.cursorId !== undefined && c.words !== undefined)[0] || null;
    }
    function line(id) {
        return all(chooser(), c => c.row !== undefined && c.current !== undefined).find(c => c.row.id === id);
    }
    // The eye of a row
    function eye(id) {
        return all(line(id), c => c.objectName === "eyeButton")[0];
    }
    function body(address) {
        return scene.world.bodyList().find(b => b.address === address);
    }
    function blackHole() {
        return all(scene, c => c.lensRadius !== undefined && c.eye !== undefined)[0];
    }
    function chip() {
        return all(chooser(), c => c.objectName === "carryChip")[0];
    }
    function heading() {
        return all(chooser(), c => c.objectName === "hiddenHeading")[0];
    }
    // The command that lists the wired outputs ends with the made-up listing
    function read() {
        const run = ProcessLog.live.filter(p => p.command[0] === "pactl" && p.command.indexOf("sinks") >= 0 && p.running)[0];
        run.stdout.text = listing;
        run.running = false;
        run.exited(0);
    }
    function open(address) {
        scene.openMenu(body(address), Qt.point(60, 60));
        menu().choose("group");
        read();
        return chooser();
    }
    // DMS keeps what the plugin saved and hands it back: here, the test does
    function stored() {
        return PluginService.saved.hiddenDevices ?? ({});
    }
    function reload() {
        // The settings DMS hands back: the Hidden section's open/closed choice comes with them
        scene.prefs._data = Object.assign({}, SettingsData.pluginSettings, PluginService.saved);
        scene.prefs.hiddenDevices = stored();
    }
    function savedOpen() {
        return PluginService.saved.hiddenSectionOpen ?? null;
    }
    function section(id) {
        return chooser().view.sections.find(s => s.id === id);
    }
    function ids(id) {
        const s = section(id);
        return s ? s.rows.map(r => r.id) : null;
    }
    // Where the black hole is, in a row's own coordinates, and far from it
    function atHole(id) {
        return line(id).mapFromItem(scene, scene.holeX, scene.holeY);
    }
    function awayFromHole(id) {
        return line(id).mapFromItem(scene, scene.holeX, scene.holeY - scene.height);
    }

    readonly property var steps: [
        {
            "then": 1000,
            "run": () => {}
        },
        {
            // The black hole at rest: as big as it always was
            "then": 100,
            "run": () => {
                const hole = h.blackHole();
                check("the scene's own view: the hole is its nominal size, whatever its height", [scene.centre.profile, hole.lean, hole.horizon], [0, 1, Math.round(scene.bodySize * 0.2)]);
                check("the drag gestures measure from it", scene.holeHorizon, hole.horizon);
                check("nothing hidden: the counter is empty", [scene.hiddenCount, hole.eye], [0, false]);
            }
        },
        {
            // The chooser: no Hidden section, an eye only where the pointer is
            "then": 100,
            "run": () => {
                const c = h.open(h.headset);
                check("nothing hidden: no Hidden section", [c.anyHidden, c.view.sections.map(s => s.id)], [false, ["wired", "bluetooth"]]);
                check("no row shows its eye while nobody points at it", [h.hdmi, h.usb, h.one].map(id => h.eye(id).visible), [false, false, false]);
                h.line(h.usb).hovered();
                check("the row under the pointer does", [h.usb, h.hdmi].map(id => h.eye(id).visible), [true, false]);
                c.press(Qt.Key_Down);
                check("and the one the keys are on (keyboard focus)", [c.cursorId !== h.usb, h.eye(c.cursorId).visible], [true, true]);
            }
        },
        {
            // The eye of a wired output hides it, in the store of the hole
            "then": 100,
            "run": () => {
                const c = h.chooser();
                h.line(h.usb).hovered();
                h.line(h.usb).eye();
                check("the eye of a wired output stores it, by its node name and the name it had", h.stored(), {
                    [h.usb]: "Interface Stereo"
                });
                check("not stored yet by the scene: the list still shows it until DMS hands the settings back", h.ids("wired").indexOf(h.usb) >= 0, true);
                h.reload();
                check("then it leaves Wired", h.ids("wired"), [h.hdmi]);
                check("the first time, the Hidden section appears open by itself, with its row (D368)", [h.section("hidden").count, h.section("hidden").rows.length, c.hiddenOpen, h.savedOpen()], [1, 1, true, true]);
                check("the hole's counter counts it too, and its card lists it", [scene.hiddenCount, Object.keys(scene.prefs.hiddenDevices)], [1, [h.usb]]);
                check("it is not ticked any more, whatever was ticked", c.view.chosen, [h.headset]);
                check("the chooser stays open", [!!h.chooser(), scene.menuOpen], [true, true]);
            }
        },
        {
            // The Hidden section: folded, opened by its heading, each row with an eye that brings it back
            "then": 100,
            "run": () => {
                const c = h.chooser();
                h.heading().clicked(null);
                check("its heading folds it, and the choice is kept", [c.hiddenOpen, h.ids("hidden"), h.savedOpen()], [false, [], false]);
                h.heading().clicked(null);
                check("and opens it again", [c.hiddenOpen, h.ids("hidden"), h.savedOpen()], [true, [h.usb], true]);
                const r = h.section("hidden").rows[0];
                check("a hidden row has the picture and name of the output, and cannot be ticked", [r.icon, r.label, r.ticked, r.why], ["usb", "Interface Stereo", false, "hidden"]);
                check("it is a row of the keyboard cursor now", c.rows.map(x => x.id).indexOf(h.usb) >= 0, true);
                check("its eye brings it back (an open eye)", [h.line(h.usb).away, h.line(h.usb).row.section], [true, "hidden"]);
                h.line(h.usb).hovered();
                h.line(h.usb).eye();
                check("brought back: the store is empty again", h.stored(), {});
                h.reload();
                check("it is in Wired again, and the Hidden section is gone, folded", [h.ids("wired"), c.anyHidden, c.hiddenOpen, scene.hiddenCount], [[h.hdmi, h.usb], false, false, 0]);
                c.press(Qt.Key_Down);
            }
        },
        {
            // The keys: H hides the row, Right opens the Hidden section, Left folds it
            "then": 100,
            "run": () => {
                const c = h.chooser();
                h.line(h.hdmi).hovered();
                c.press(Qt.Key_H);
                check("H hides the row under the cursor", Object.keys(h.stored()), [h.hdmi]);
                h.reload();
                check("hiding again does not open it by itself: it was chosen already", [c.hiddenOpen, c.anyHidden], [false, true]);
                check("the Hidden section is there; Right opens it, Left folds it", [c.press(Qt.Key_Right), c.hiddenOpen, h.ids("hidden"), c.press(Qt.Key_Left), c.hiddenOpen], [true, true, [h.hdmi], true, false]);
                h.line(h.usb).hovered();
                h.line(h.usb).eye();
                h.reload();
                check("two hidden: the count is two", [h.section("hidden").count, scene.hiddenCount], [2, 2]);
                scene.prefs.hiddenDevices = ({});
                check("the Right key is not for the chooser when nothing is hidden", c.press(Qt.Key_Right), false);
            }
        },
        {
            // A row carried to the black hole: the chip, the eye of the hole, the drop
            "then": 100,
            "run": () => {
                const c = h.chooser();
                const hole = h.blackHole();
                h.line(h.hdmi).carried(h.awayFromHole(h.hdmi));
                check("carried away from the hole: the chip follows, nothing lights up", [h.chip().visible, c.overHole, scene.holeFeed, scene.holeEye], [true, false, 0, true]);
                h.line(h.hdmi).carried(h.atHole(h.hdmi));
                check("carried over it: the hole feeds and shows an eye", [c.overHole, scene.holeFeed > 0.5, scene.holeEye, hole.eye], [true, true, true, true]);
                h.line(h.hdmi).dropped(h.atHole(h.hdmi));
                check("let go over it: the output is hidden", Object.keys(h.stored()), [h.hdmi]);
                check("and the hole calms down, the chip is gone", [scene.holeFeed, scene.holeEye, c.carrying, h.chip().visible], [0, false, null, false]);
                scene.prefs.hiddenDevices = ({});
                PluginService.saved = ({});
                h.line(h.hdmi).carried(h.awayFromHole(h.hdmi));
                h.line(h.hdmi).dropped(h.awayFromHole(h.hdmi));
                check("counter-proof: let go anywhere else, nothing is hidden", [h.stored(), scene.holeFeed, scene.holeEye], [
                    {},
                    0, false]);
                h.line(h.hdmi).carried(h.atHole(h.hdmi));
                h.menu().close();
            }
        },
        {
            // Closed while a row was carried: the hole stops feeding
            "then": 100,
            "run": () => {
                check("closed with a row in the air, the hole is not left lit", [h.chooser(), scene.holeFeed, scene.holeEye], [null, 0, false]);
            }
        },
        {
            // A Bluetooth device: it spirals into the hole like one dragged there
            "then": 100,
            "run": () => {
                const c = h.open(h.one);
                h.line(h.two).hovered();
                h.line(h.two).eye();
                check("the eye of a Bluetooth device sends it into the hole", [h.body(h.two).swallowing, h.ids("bluetooth").indexOf(h.two)], [true, -1]);
            }
        },
        {
            "then": 1800,
            "run": () => {
                // The end of the fall is the body's own animation (DeviceBody); the scene's answer to it is what is tested here
                scene.finishHide(h.body(h.two));
                check("once it is in, it is stored under its address", Object.keys(h.stored()), [h.two]);
                h.reload();
                check("and waits in Hidden", [h.chooser().anyHidden, h.chooser().view.sections.find(s => s.id === "hidden").count], [true, 1]);
                h.menu().close();
                scene.prefs.hiddenDevices = ({});
                PluginService.saved = ({});
                route.sharing = [h.headset, h.one];
            }
        },
        {
            // A member of the group is not hidden: the note says why
            "then": 1800,
            "run": () => {
                const c = h.open(h.two);
                scene.note = null;
                h.line(h.one).hovered();
                h.line(h.one).eye();
                check("a member is not hidden: it is told to leave first, with the way to the guide", scene.note ? [scene.note.title.endsWith(" listens together"), scene.note.anchor] : null, [true, "hiding-devices-the-black-hole"]);
                check("nothing was stored for the member, and the chooser is still open", [h.stored()[h.one], !!h.chooser(), h.body(h.one).swallowing], [undefined, true, false]);
                scene.note = null;
                h.line(h.one).carried(h.atHole(h.one));
                h.line(h.one).dropped(h.atHole(h.one));
                check("carried to the hole, the same: said, not done", [scene.note ? scene.note.anchor : null, h.stored()[h.one]], ["hiding-devices-the-black-hole", undefined]);
                scene.note = null;
                h.menu().close();
            }
        },
        {
            // The profile view: the hole is as big as its depth says, and as small as
            // the host's system while the group has the centre
            "then": 1500,
            "run": () => {
                const hole = h.blackHole();
                check("a group has the centre: the scene is in profile, the host's system is away", [scene.centre.profile, scene.centre.away], [1, 1]);
                const lean = Perspective.leanAt(scene, scene.holeY, 1) * Sun.SIZE;
                check("the hole is drawn at the size of its depth and of the host's system, and the drag gestures measure from that", [Math.abs(hole.lean - lean) < 1e-9, hole.horizon, scene.holeHorizon], [true, Math.round(scene.bodySize * 0.2 * lean), Math.round(scene.bodySize * 0.2 * lean)]);
                // The hole drifts in the outer field: wherever it floats, even on the nearest point of the belt, it is smaller than in the scene's own view
                check("so it is smaller than in the scene's own view, wherever it floats", [hole.horizon < Math.round(scene.bodySize * 0.2), Perspective.lean(1, 1) * Sun.holeScale(1) < 1], [true, true]);
                check("it follows the depth, wherever it floats: smaller when high in the belt, bigger when low", [Perspective.leanAt(scene, scene.cy - scene.ry, 1) < 1, Perspective.leanAt(scene, scene.cy + scene.ry, 1) > 1], [true, true]);
                check("its picture is as wide as its lens", hole.width, hole.lensRadius * 2);
                route.sharing = [];
            }
        },
        {
            "then": 1500,
            "run": () => {
                const hole = h.blackHole();
                check("counter-proof: back in the scene's own view it is its nominal size again", [scene.centre.profile, hole.lean, hole.horizon], [0, 1, Math.round(scene.bodySize * 0.2)]);
            }
        }
    ]
    property int step: 0
    Timer {
        interval: 25000
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
