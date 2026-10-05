import QtQuick
import qs.Common
import qs.Services
import "components/scene"
import "components/radar/Radar.js" as Radar
import "mock"
import "mock/State.js" as State
import "mock/Devices.js" as Devices

// Test of the volume radar of a listening group: it is not there at rest; a tap
// on the group's icons opens it on the group's level; a click on a Bluetooth
// member or on a wired member opens it on theirs (never the old detail card,
// which Details still reaches); the gestures move the group's level and a
// member's own one, and mute; the hero's actions do their job (Remove from group,
// Add a device…, Stop group); and Escape's way back (stepBack) closes it. Run with tests/qml/run.sh.
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
    function disc(address) {
        return scene.world.wiredMembers.list().find(b => b.address === address) ?? null;
    }
    // The radar's drawn view, null while it is closed (the Loader makes it on demand)
    function view(item) {
        for (const child of item.children) {
            if ("slotOf" in child)
                return child;
            const found = view(child);
            if (found)
                return found;
        }
        return null;
    }
    // The right-click menu, found like the radar's view
    function menu(item) {
        for (const child of item.children) {
            if ("choosing" in child && "entries" in child)
                return child;
            const found = menu(child);
            if (found)
                return found;
        }
        return null;
    }
    // A note of the radar's own layer is on screen, above the radar's view
    function noteOver() {
        const notes = [];
        const walk = item => {
            for (const child of item.children) {
                if ("info" in child && "scene" in child && child.visible && child.z >= 20000 && child.parent !== scene)
                    notes.push(child);
                walk(child);
            }
        };
        walk(h.radar);
        return notes.length === 1 && !!notes[0].info;
    }
    function near(a, b) {
        return Math.abs(a - b) < 0.011;
    }
    readonly property bool landed: scene.centre.grouping === 1 && !scene.centre.travelling
    readonly property var radar: scene.radar

    readonly property var steps: [
        {
            "then": 100,
            "until": () => h.landed,
            "run": () => {
                SettingsData.reduceMotion = true;
                route.sharing = [h.headset, h.one, h.dac];
            }
        },
        {
            "then": 100,
            "until": () => h.landed && h.disc(h.dac),
            "run": () => {
                check("at rest nothing of the radar exists", [h.radar.open, h.view(scene)], [false, null]);
                check("the group is the headset, a Bluetooth copy and a wired one", [scene.centre.source, scene.centre.members.length], [h.headset, 3]);
                h.radar.show("");
            }
        },
        {
            "then": 100,
            "run": () => {
                check("a tap on the group's icons: the radar on the group's level", [h.radar.open, h.radar.heroId, h.radar.kindOf(h.radar.heroId)], [true, "group", "group"]);
                check("its dials are the group's, then each member's", h.radar.ids, ["group", h.headset, h.one, h.dac]);
                check("it is drawn, with a dial for each", [!!h.view(scene), h.view(scene).children.length > 4], [true, true]);
                check("Escape's way back sees it", scene.canStepBack, true);
                check("the group's actions", [Radar.chips("group").map(c => c.id)], [["add", "stop"]]);
                h.radar.close();
                check("closed: gone again", [h.radar.open, h.view(scene)], [false, null]);
                h.radar.show("");
                scene.explain({
                    "title": "A note",
                    "hint": "Said over the veil",
                    "anchor": ""
                });
                check("a guided note is drawn over the open radar, above its veil", h.noteOver(), true);
                h.radar.close();
                scene.focusOn(scene.centre.bodyOf(h.one));
            }
        },
        {
            "then": 100,
            "run": () => {
                check("a click on a Bluetooth member: the radar on its level, no detail card", [h.radar.open, h.radar.heroId, h.radar.kindOf(h.radar.heroId), scene.focusBody], [true, h.one, "bluetooth", null]);
                h.radar.close();
                scene.focusOn(h.disc(h.dac));
            }
        },
        {
            "then": 100,
            "run": () => {
                check("a click on a wired member: the radar on its level", [h.radar.open, h.radar.heroId, h.radar.kindOf(h.radar.heroId), scene.focusBody], [true, h.dac, "wired", null]);
                // The gestures on the wired member's own level
                const before = scene.centre.volume.ownLevel(h.dac);
                h.radar.step(h.dac, 1);
                check("the wheel raises its own level", scene.centre.volume.ownLevel(h.dac) > before, true);
                h.radar.setLevel(h.dac, 0.3);
                check("a drag sets its level", h.near(scene.centre.volume.ownLevel(h.dac), 0.3), true);
                h.radar.toggleMute(h.dac);
                check("the speaker mutes it", scene.centre.volume.ownNode(h.dac).audio.muted, true);
                h.radar.toggleMute(h.dac);
                check("and lets it speak again", scene.centre.volume.ownNode(h.dac).audio.muted, false);
                // The group's level
                h.radar.setLevel("group", 0.5);
                check("a drag on the group's dial sets the general level", h.near(scene.centre.volume.level, 0.5), true);
                h.radar.close();
                scene.focusOn(scene.centre.bodyOf(h.one));
            }
        },
        {
            "then": 100,
            "run": () => {
                check("a Bluetooth hero offers Disconnect, Remove from group, Hide, Details", Radar.chips(h.radar.kindOf(h.radar.heroId)).map(c => c.id), ["disconnect", "leave", "hide", "details"]);
                h.radar.choose("details");
                check("Details closes the radar and opens the detail card", [h.radar.open, !!scene.focusBody && scene.focusBody.address], [false, h.one]);
                scene.clearFocus();
                h.radar.show(h.one);
            }
        },
        {
            "then": 100,
            "run": () => {
                h.radar.choose("leave");
                check("Remove from group: it is out and the others stay", [scene.together.members().includes(h.one), scene.together.count()], [false, 2]);
                check("the radar goes back to the group's level", [h.radar.open, h.radar.heroId], [true, "group"]);
                scene.stepBack();
                check("Escape's way back closes it, and leaves the group's view alone", [h.radar.open, scene.focusBody, scene.centre.recalled], [false, null, false]);
                h.radar.show("");
            }
        },
        {
            "then": 100,
            "run": () => {
                h.radar.choose("add");
                check("Add a device… closes the radar and opens the group chooser, the menu's entries out of the way", [h.radar.open, scene.menuOpen, h.menu(scene).choosing], [false, true, true]);
                h.menu(scene).close();
                h.radar.show("");
            }
        },
        {
            "then": 100,
            "run": () => {
                try {
                    h.radar.choose("stop");
                } catch (e) {
                    // The stubbed session has no end(): the radar was closed before it was asked
                }
                check("Stop group closes the radar (the session's end is the daemon's, not stubbed here)", h.radar.open, false);
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
