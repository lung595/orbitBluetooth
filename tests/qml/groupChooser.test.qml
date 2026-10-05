import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import "components/scene"
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Test of the group chooser (D298), the page of the right-click menu where a
// Listen together group is made, on the whole scene with made-up devices and a
// made-up `pactl` listing: the menu offers it to the devices that play sound;
// it lists the wired outputs plugged in and the Bluetooth ones that are
// connected, the device it was opened on ticked; ticking, the button, the keys
// and the cap of four; a row that cannot be ticked and a button that is not
// ready say why, with the way to the guide, and the chooser stays open
// (value 10); a group there is takes the newcomers; the chooser stays inside
// the sky and its list scrolls; Reduce motion; and closed, nothing of it is
// left, not even the command (value 6). Run with tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string two: "02:00:00:00:20:02"
    readonly property string buds: "00:11:22:33:44:55"
    readonly property string pad: "98:7A:14:22:C1:0E"
    readonly property string mouse: "D4:1A:88:10:5B:77"
    readonly property string usb: "alsa_output.usb-Maker_Interface-00.analog-stereo"
    readonly property string hdmi: "alsa_output.pci-0000_01_00.1.hdmi-stereo"

    // What `pactl --format=json list sinks` says on the made-up machine: an
    // audio interface and a monitor plugged in, and a jack with nothing in it
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
        },
        {
            "name": "alsa_output.pci-0000_00_1f.3.analog-stereo",
            "description": "Built-in Audio",
            "active_port": "analog-output-headphones",
            "ports": [
                {
                    "name": "analog-output-headphones",
                    "availability": "not available"
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

    // Every item under `root` that `pred` accepts
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
    // The row of the chooser for this output
    function line(id) {
        return all(chooser(), c => c.row !== undefined && c.current !== undefined).find(c => c.row.id === id);
    }
    // The mark of where the part in view sits, for a list that is cut short
    function mark(c) {
        return all(c, x => x.objectName === "scrollMark")[0];
    }
    // The text of a row's name
    function nameOf(id) {
        return all(line(id), x => x.text !== undefined && x.text === line(id).row.label)[0];
    }
    function body(address) {
        return scene.world.bodyList().find(b => b.address === address);
    }
    // The commands that list the sound outputs that exist now: the scene's own
    // card keeps one at rest (`base`), and the chooser's is on top of it
    property int base: 0
    function sinks() {
        return ProcessLog.live.filter(p => p.command[0] === "pactl" && p.command.indexOf("sinks") >= 0);
    }
    function reading() {
        return sinks().filter(p => p.running);
    }
    // How many the chooser holds
    function held() {
        return sinks().length - base;
    }
    // The command that runs ends with this output
    function read(text) {
        const run = reading()[0];
        run.stdout.text = text;
        run.running = false;
        run.exited(0);
    }
    // The menu on a device, its entries' ids, and closed again
    function entriesOf(address) {
        scene.openMenu(body(address), Qt.point(60, 60));
        const ids = menu().entries.map(e => e.id);
        menu().close();
        return ids;
    }
    // The chooser opened from the menu of a device, its wired outputs read
    function open(address, point) {
        scene.openMenu(body(address), point || Qt.point(60, 60));
        menu().choose("group");
        read(listing);
        return chooser();
    }
    function ticks(c) {
        return c.view.chosen;
    }
    function rowsOf(c) {
        return c.rows.map(r => [r.id, r.ticked, r.locked, r.why]);
    }

    readonly property var steps: [
        {
            "then": 1000,
            "run": () => {}
        },
        {
            // The menu offers a group to what plays sound
            "then": 100,
            "run": () => {
                h.base = h.sinks().length;
                check("at rest there is no chooser, no command that runs and no menu", [h.chooser(), h.reading().length, scene.menuOpen], [null, 0, false]);
                const ids = h.entriesOf(h.headset);
                check("a connected device that plays sound is offered a group, among the Listen together entries", [ids.indexOf("group") > 0, ids.indexOf("group") < ids.indexOf("hide")], [true, true]);
                scene.openMenu(h.body(h.headset), Qt.point(60, 60));
                check("it reads Create a group…", h.menu().entries.find(e => e.id === "group"), {
                    "id": "group",
                    "icon": "group_add",
                    "label": "Create a group…",
                    "rule": true
                });
                h.menu().close();
                check("so is a speaker", h.entriesOf(h.one).indexOf("group") >= 0, true);
                check("a controller, connected but with no sound, is not", h.entriesOf(h.pad).indexOf("group") >= 0, false);
                check("a device that is not connected is not", h.entriesOf(h.mouse).indexOf("group") >= 0, false);
                check("a headset whose sound output is not there yet is not", h.entriesOf(h.buds).indexOf("group") >= 0, false);
                route.inCall = [h.two];
                check("one in call mode is: the chooser tells it to wait", h.entriesOf(h.two).indexOf("group") >= 0, true);
                route.inCall = [];
                check("and the menu is closed again, with nothing started", [scene.menuOpen, h.held(), h.reading().length], [false, 0, 0]);
            }
        },
        {
            // The chooser: what it lists
            "then": 100,
            "run": () => {
                scene.openMenu(h.body(h.headset), Qt.point(60, 60));
                h.menu().choose("group");
                const c = h.chooser();
                check("Create a group… opens the chooser; the menu stays open", [!!c, h.menu().choosing, scene.menuOpen], [true, true, true]);
                check("it says a group is made", [c.words.title, c.words.action], ["Create a group", "Listen together"]);
                check("it asked for the wired outputs once, and the command runs", [h.held(), h.reading().length], [1, 1]);
                check("until they are read only the Bluetooth outputs are listed", c.view.sections.map(s => s.id), ["bluetooth"]);
                check("and the chooser is not shown yet: it waits for them, so that nothing moves as it opens", [c.listed, c.opacity], [false, 0]);
                h.read(h.listing);
                check("it is shown once they are read", [c.listed, c.opacity], [true, 1]);
                check("then the wired ones come first, each section by name, and what is unplugged is not there", c.view.sections.map(s => [s.id, s.rows.map(r => r.id)]), [["wired", [h.hdmi, h.usb]], ["bluetooth", [h.buds, h.two, h.one, h.headset]]]);
                check("the device the menu was opened on is ticked, and nothing else", [h.ticks(c), c.rows.filter(r => r.ticked).map(r => r.id)], [[h.headset], [h.headset]]);
                check("every row is drawn once", h.all(c, x => x.row !== undefined && x.current !== undefined).length, 6);
                check("an output with no sound yet is listed, and says so", c.rows.find(r => r.id === h.buds), {
                    "section": "bluetooth",
                    "id": h.buds,
                    "label": "HUAWEI FreeBuds Pro",
                    "icon": c.rows.find(r => r.id === h.buds).icon,
                    "ticked": false,
                    "locked": false,
                    "why": "no-audio",
                    "caption": "No sound yet"
                });
                check("the controller and the device that is away are not offered", c.rows.filter(r => r.id === h.pad || r.id === h.mouse).length, 0);
                check("enough to make a group of: no empty hint, the button is shown", [c.empty, c.plan.why], [false, "pick-more"]);
                check("the wired outputs have their own pictures", c.rows.filter(r => r.section === "wired").map(r => r.icon), ["settings_input_hdmi", "usb"]);
            }
        },
        {
            // Ticking, and what cannot be ticked
            "then": 100,
            "run": () => {
                const c = h.chooser();
                h.line(h.usb).clicked();
                check("a click ticks a wired output", h.ticks(c), [h.headset, h.usb]);
                h.line(h.two).clicked();
                check("and a Bluetooth one, in the order of the clicks", h.ticks(c), [h.headset, h.usb, h.two]);
                h.line(h.usb).clicked();
                check("a second click unticks it", h.ticks(c), [h.headset, h.two]);
                h.line(h.buds).clicked();
                check("a row that cannot be ticked says why, with the way to the guide", scene.note ? [scene.note.title, scene.note.anchor] : null, ["HUAWEI FreeBuds Pro has no sound output yet", "works-with-multipoint-headsets"]);
                check("the chooser stays open and nothing changed", [!!h.chooser(), h.ticks(c), route.sharing], [true, [h.headset, h.two], []]);
                scene.note = null;
                h.line(h.two).clicked();
                c.confirm();
                check("a button pressed with one output is told to tick another, and the group is not made", [scene.note ? scene.note.title : null, scene.note ? scene.note.anchor : null, route.sharing, !!h.chooser()], ["Tick another output", "listen-together", [], true]);
                scene.note = null;
            }
        },
        {
            // What no longer can be ticked falls out of the ticks, live
            "then": 100,
            "run": () => {
                const c = h.chooser();
                h.line(h.two).clicked();
                check("an output ticked again", h.ticks(c), [h.headset, h.two]);
                route.inCall = [h.two];
                check("it goes into call mode while the chooser is open: it falls out of the ticks and says so on its row", [h.ticks(c), c.rows.find(r => r.id === h.two).caption], [[h.headset], "Call mode"]);
                h.line(h.two).clicked();
                check("clicked, it says it is in call mode", scene.note ? scene.note.title : null, "JBL Charge 5 is in call mode");
                route.inCall = [];
                check("back to music: it can be ticked again, and what was ticked is ticked", [c.rows.find(r => r.id === h.two).why, h.ticks(c)], ["", [h.headset, h.two]]);
                h.line(h.two).clicked();
                check("unticked for what follows", h.ticks(c), [h.headset]);
                scene.note = null;
            }
        },
        {
            // Validating
            "then": 100,
            "run": () => {
                const c = h.chooser();
                h.line(h.hdmi).clicked();
                h.line(h.one).clicked();
                check("three outputs are ticked", h.ticks(c), [h.headset, h.hdmi, h.one]);
                c.confirm();
                check("the button starts the group with them, in the order ticked", route.sharing, [h.headset, h.hdmi, h.one]);
                check("the menu is closed", [scene.menuOpen, h.menu().choosing, !!h.chooser()], [false, false, false]);
            }
        },
        {
            // Closed: nothing of it is left
            "then": 100,
            "run": () => {
                check("closed: the command is gone with it, nothing runs", [h.chooser(), h.held(), h.reading().length], [null, 0, 0]);
            }
        },
        {
            // A member: it is in the group already, so its menu has no group entry, and the page that adds another device is the radar's
            "then": 100,
            "run": () => {
                scene.openMenu(h.body(h.one), Qt.point(60, 60));
                check("a member's menu leaves it or hides it, it does not make or add to a group", [h.menu().entries.map(e => e.label), h.menu().entries.some(e => e.id === "group" || e.id === "separate")], [["Disconnect", "Remove from group", "Hide", "Forget"], false]);
                h.menu().close();
                h.menu().addDevices(h.body(h.one), Qt.point(60, 60));
                check("the group's radar adds a device by the same page: the chooser, the menu's entries out of the way", [h.menu().choosing, !!h.chooser(), scene.menuOpen], [true, true, true]);
                h.read(h.listing);
                const c = h.chooser();
                check("its chooser still says the group is added to, and starts with nothing ticked", [c.words.title, c.words.action, h.ticks(c)], ["Add to the group", "Add", []]);
                c.confirm();
                check("pressing the button with nothing ticked asks to tick one", scene.note ? scene.note.title : null, "Tick another output");
                scene.note = null;
                h.menu().close();
                scene.openMenu(h.body(h.two), Qt.point(60, 60));
                check("while the menu of a device that is not in the group keeps saying so", h.menu().entries.find(e => e.id === "group").label, "Add to the group…");
                h.menu().close();
            }
        },
        {
            // The listing is slow, or never comes: the chooser is shown without it
            "then": 700,
            "run": () => {
                scene.openMenu(h.body(h.headset), Qt.point(60, 60));
                h.menu().choose("group");
                check("the wired outputs are not read yet: the chooser waits", [h.chooser().opacity, h.reading().length], [0, 1]);
            }
        },
        {
            "then": 100,
            "run": () => {
                const c = h.chooser();
                check("they never came: it is shown without them after a moment", [c.opacity, c.view.sections.map(s => s.id)], [1, ["bluetooth"]]);
                h.menu().close();
                check("closed while the command ran: the command is gone with it", [h.held(), h.reading().length], [0, 0]);
            }
        },
        {
            // A group there is takes the newcomers
            "then": 100,
            "run": () => {
                scene.openMenu(h.body(h.two), Qt.point(60, 60));
                check("with a group, the entry says Add to the group…", h.menu().entries.find(e => e.id === "group").label, "Add to the group…");
                h.menu().choose("group");
                h.read(h.listing);
                const c = h.chooser();
                check("and so does the chooser", [c.words.title, c.words.action], ["Add to the group", "Add"]);
                check("the members are ticked and locked, the device it was opened on is ticked, there is room for one more", h.rowsOf(c), [[h.hdmi, true, true, "already"], [h.usb, false, false, "full"], [h.buds, false, false, "no-audio"], [h.two, true, false, ""], [h.one, true, true, "already"], [h.headset, true, true, "already"]]);
                check("a member stays in the ink, and only what is ticked to be added stands out", [h.line(h.one).added, h.line(h.two).added, h.line(h.usb).added, Qt.colorEqual(h.nameOf(h.one).color, Theme.primary), Qt.colorEqual(h.nameOf(h.two).color, Theme.primary)], [false, true, false, false, true]);
                h.line(h.usb).clicked();
                check("the group is full: it says so, and nothing changed", [scene.note ? scene.note.title : null, h.ticks(c)], ["The group is full", [h.two]]);
                scene.note = null;
                h.line(h.headset).clicked();
                check("a member says that it is in the group already", scene.note ? scene.note.title : null, "WH-1000XM6 already listens together");
                scene.note = null;
                h.line(h.two).clicked();
                c.confirm();
                check("nothing ticked to add: it asks to tick one", [scene.note ? scene.note.title : null, route.sharing], ["Tick another output", [h.headset, h.hdmi, h.one]]);
                scene.note = null;
                h.line(h.two).clicked();
                c.confirm();
                check("the button adds what is ticked to the group", route.sharing, [h.headset, h.hdmi, h.one, h.two]);
                check("and the chooser is closed", [scene.menuOpen, !!h.chooser()], [false, false]);
            }
        },
        {
            // The session says no after the chooser has closed (it was a moment ago
            // that the output was there)
            "then": 100,
            "run": () => {
                route.refusal = {
                    "why": "not-connected",
                    "address": ""
                };
                scene.together.groupFrom([h.usb]);
                check("a refusal of the session is said, and nothing changed", [scene.note ? scene.note.title : null, route.sharing], ["This device is not connected", [h.headset, h.hdmi, h.one, h.two]]);
                route.refusal = null;
                scene.note = null;
                scene.together.groupFrom([]);
                check("nothing to add is told, not done", [scene.note ? scene.note.title : null, route.sharing], ["Tick another output", [h.headset, h.hdmi, h.one, h.two]]);
                scene.note = null;
                route.sharing = [];
            }
        },
        {
            // The keys
            "then": 100,
            "run": () => {
                const c = h.open(h.headset);
                check("a key that is not the chooser's is left alone", c.press(Qt.Key_A), false);
                check("Down enters the list at the top", [c.press(Qt.Key_Down), c.cursorId], [true, h.hdmi]);
                c.press(Qt.Key_Down);
                check("and goes down", c.cursorId, h.usb);
                c.press(Qt.Key_Up);
                c.press(Qt.Key_Up);
                check("it stops at the first row", c.cursorId, h.hdmi);
                c.press(Qt.Key_Space);
                check("Space ticks the row under the cursor", h.ticks(c), [h.headset, h.hdmi]);
                c.press(Qt.Key_Space);
                check("and unticks it", h.ticks(c), [h.headset]);
                c.press(Qt.Key_Down);
                c.press(Qt.Key_Down);
                c.press(Qt.Key_Space);
                check("Space on a row that cannot be ticked says why", [c.cursorId, scene.note ? scene.note.title : null], [h.buds, "HUAWEI FreeBuds Pro has no sound output yet"]);
                scene.note = null;
                c.press(Qt.Key_Return);
                check("Enter is the button: one output is not a group", [scene.note ? scene.note.title : null, route.sharing], ["Tick another output", []]);
                scene.note = null;
                for (let i = 0; i < 9; i++)
                    c.press(Qt.Key_Down);
                check("it stops at the last row", c.cursorId, h.headset);
                for (let i = 0; i < 4; i++)
                    c.press(Qt.Key_Up);
                check("up again", c.cursorId, h.usb);
                c.press(Qt.Key_Space);
                check("a second output ticked with the keys", h.ticks(c), [h.headset, h.usb]);
                check("Enter makes the group", [c.press(Qt.Key_Enter), route.sharing], [true, [h.headset, h.usb]]);
                route.sharing = [];
            }
        },
        {
            // Inside the sky, and the list scrolls rather than leave it
            "then": 100,
            "run": () => {
                const c = h.open(h.headset, Qt.point(scene.width, scene.height));
                check("opened in a corner, it stays inside the sky and leaves room for the note", [c.x >= 8, c.x + c.width <= scene.width - 8, c.y >= 8, c.y + c.height <= scene.height - c.bottomRoom], [true, true, true, true]);
                const list = h.all(c, x => x.contentY !== undefined)[0];
                check("in a tall sky the whole list shows: it does not scroll, and has no mark", [list.interactive, list.height === list.contentHeight, h.mark(c).visible], [false, true, false]);
                // A refusal is read while the chooser is open: the note says it under
                // the chooser, never behind it
                scene.explain({
                    "title": "A title",
                    "hint": "What to do, in a line that is long enough to be wide",
                    "anchor": "listen-together"
                });
                const note = h.all(scene, x => x.info !== undefined && x.z === 20000)[0];
                check("the note shown at the bottom does not touch the chooser", note.mapToItem(scene, 0, 0).y >= c.y + c.height, true);
                scene.note = null;
                // A click that misses a row must not reach the menu's own catch-all,
                // which closes it: a catch-all area under the rows takes it
                const catcher = c.children.find(x => x.acceptedButtons === Qt.AllButtons);
                check("a catch-all area covers the chooser, below its rows", [!!catcher, catcher.width === c.width, catcher.height === c.height, c.children.indexOf(catcher) < c.children.findIndex(x => x.spacing !== undefined)], [true, true, true, true]);
                h.menu().close();
                h.height = 300;
            }
        },
        {
            "then": 100,
            "run": () => {
                const c = h.open(h.headset, Qt.point(scene.width, scene.height));
                const list = h.all(c, x => x.contentY !== undefined)[0];
                check("in a short sky the list is capped, and scrolls", [list.height <= c.maxList, list.interactive, list.contentHeight > list.height], [true, true, true]);
                check("and the chooser is still inside the sky", [c.y >= 8, c.y + c.height <= scene.height - c.bottomRoom], [true, true]);
                check("at the top to begin with", list.contentY, 0);
                // A mark says that there is more, whichever way the cut falls
                const mark = h.mark(c);
                const top = list.mapToItem(c, 0, 0).y;
                check("a mark shows that there is more: shorter than the list, at its top", [mark.visible, mark.height < list.height, Math.abs(mark.y - (top + 2)) < 0.5], [true, true, true]);
                for (let i = 0; i < 6; i++)
                    c.press(Qt.Key_Down);
                check("the last row, reached with the keys, is brought into view", [c.cursorId, list.contentY > 0, list.contentY + list.height >= list.contentHeight - 0.5], [h.headset, true, true]);
                check("and the mark has followed it to the bottom", Math.abs(mark.y + mark.height - (top + list.height - 2)) < 1, true);
                c.press(Qt.Key_Up);
                c.press(Qt.Key_Up);
                c.press(Qt.Key_Up);
                c.press(Qt.Key_Up);
                c.press(Qt.Key_Up);
                c.press(Qt.Key_Up);
                check("and the first one back", [c.cursorId, list.contentY], [h.hdmi, 0]);
                h.menu().close();
                h.height = 440;
            }
        },
        {
            // Reduce motion
            "then": 100,
            "run": () => {
                SettingsData.reduceMotion = true;
                const c = h.open(h.headset);
                check("Reduce motion: the chooser is in place at once", c.scale, 1);
                h.menu().close();
                SettingsData.reduceMotion = false;
            }
        },
        {
            // The grow takes 140 ms: it is read at once, and again once it is over
            "then": 400,
            "run": () => {
                const c = h.open(h.headset);
                check("motion on (counter-proof): it grows into place", c.scale < 1, true);
            }
        },
        {
            "then": 100,
            "run": () => {
                const c = h.chooser();
                check("and it has arrived", c.scale, 1);
                check("the chooser has the keyboard, for the keys", c.activeFocus, true);
                h.menu().close();
            }
        },
        {
            "then": 100,
            "run": () => {
                check("closed by the menu: no chooser, no command, no menu", [h.chooser(), h.held(), scene.menuOpen, h.menu().choosing], [null, 0, false, false]);
                const c = h.open(h.headset);
                scene.dismiss();
                check("the scene dismissing its overlays closes it too", [!!h.chooser(), scene.menuOpen], [false, false]);
                scene.openMenu(h.body(h.headset), Qt.point(60, 60));
                check("a new menu shows its entries, not the chooser", [h.menu().choosing, !!h.chooser()], [false, false]);
                h.menu().close();
            }
        },
        {
            "then": 100,
            "run": () => {
                check("everything is gone: no chooser, no command", [h.chooser(), h.held(), h.reading().length], [null, 0, 0]);
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
