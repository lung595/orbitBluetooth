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

    // The effects clock moves once per physics step: counting its changes counts the steps
    property bool counting: false
    property int stepsCounted: 0
    Connections {
        target: scene
        function onFxTimeChanged() {
            if (h.counting)
                h.stepsCounted++;
        }
    }

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
                check("the group has no planet to fly: the card carries its picture, and the sky steps back as for any card", [scene.focusBody, scene.detailOpen, scene.cardOpen], [null, false, true]);
                check("the group's actions", [Radar.chips("group").map(c => c.id)], [["add", "stop"]]);
                h.radar.close();
                check("closed: the radar is not open, and the sky is back", [h.radar.open, scene.cardOpen], [false, false]);
            },
            // The card slides down and fades like the detail card's, and is made only until it has
            "until": () => !h.view(scene)
        },
        {
            "then": 100,
            "run": () => {
                check("gone again once it has slid away", [h.radar.open, h.view(scene)], [false, null]);
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
                check("a click on a Bluetooth member: the radar on its level, no detail card", [h.radar.open, h.radar.heroId, h.radar.kindOf(h.radar.heroId), scene.detailOpen], [true, h.one, "bluetooth", false]);
                check("its planet flies to the card, like a device's", [scene.focusBody && scene.focusBody.address, scene.focusBody && scene.focusBody.focused, scene.world.cardSlide === scene.world.radarCard.parent], [h.one, true, true]);
            },
            // The planet rises to the card and grows, as a device's does
            "until": () => {
                const b = scene.focusBody;
                return !!b && Math.abs(b.focusScale - scene.focusGlyphScale) < 0.01 && Math.abs(b.py - (scene.world.cardSlide.y + scene.focusGlyphLift)) < 2;
            }
        },
        {
            "then": 100,
            "run": () => {
                const slide = scene.world.cardSlide;
                check("the planet sits on the card's top edge, the glyph's size", [Math.abs(scene.focusBody.py - slide.y - scene.focusGlyphLift) < 3, Math.round(scene.focusBody.width * scene.focusBody.focusScale)], [true, Math.round(scene.focusGlyphSize)]);
                check("the card is the detail card's: narrow, centred, glued to the bottom", [slide.width <= 360, slide.width === scene.focusCardWidth, Math.round(slide.x * 2 + slide.width), Math.round(slide.y + slide.height + 12)], [true, true, Math.round(scene.width), Math.round(scene.height)]);
                check("the detail card stays down: it is not the radar's", [scene.world.focusCard.parent.visible, scene.world.cardSlide !== scene.world.focusCard.parent], [false, true]);
                const other = scene.centre.bodyOf(h.headset);
                check("the other planets, the host and the hint step back as for a detail card", [other.opacity < 0.5, other.hovered, scene.world.dim], [true, false, 0.12]);
                h.radar.close();
                scene.focusOn(h.disc(h.dac));
            }
        },
        {
            "then": 100,
            "run": () => {
                check("a click on a wired member: the radar on its level, no planet flies", [h.radar.open, h.radar.heroId, h.radar.kindOf(h.radar.heroId), scene.focusBody], [true, h.dac, "wired", null]);
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
                check("Escape's way back closes it, the planet comes back, and the group's view is left alone", [h.radar.open, scene.focusBody, scene.centre.recalled], [false, null, false]);
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
            "until": () => {
                const v = h.view(scene);
                return !!v && !v.entering && !v.levelsMoving && !v.clock.running;
            },
            "run": () => {
                // With motion, the entrance, a level's glide and a hero swap run on the
                // radar's one clock, which stops once they have landed
                SettingsData.reduceMotion = false;
                h.radar.close();
                h.radar.show("");
            }
        },
        {
            "then": 100,
            "run": () => {
                const v = h.view(scene);
                check("with motion the entrance has run its course and the clock has stopped", [v.motion, v.entering, v.clock.running], [true, false, false]);
                check("every drawn level has landed on the real one", v.levelsMoving, false);
                h.radar.setLevel("group", 0.2);
                check("a level that moves wakes the clock", v.clock.running, true);
                h.radar.show(h.headset);
                check("a hero swap starts the morph, on the clock", [v.morphing, v.clock.running], [true, true]);
            },
            "until": () => {
                const v = h.view(scene);
                return !v.morphing && !v.levelsMoving && !v.clock.running;
            }
        },
        {
            "then": 100,
            "run": () => {
                const v = h.view(scene);
                check("the morph ended exactly on the slots and the clock has stopped again", [v.morphing, v.levelsMoving, v.clock.running, JSON.stringify(v.slotOf(h.headset)) === JSON.stringify(v.targets[h.headset])], [false, false, false, true]);
                SettingsData.reduceMotion = true;
                h.radar.close();
                h.radar.show("");
            }
        },
        {
            "then": 100,
            "run": () => {
                const v = h.view(scene);
                check("with Reduce motion the clock never runs", [v.motion, v.entering, v.clock.running], [false, false, false]);
                h.radar.show(h.headset);
                check("and a hero swap is instant", [v.morphing, v.clock.running, JSON.stringify(v.slotOf(h.headset)) === JSON.stringify(v.targets[h.headset])], [false, false, true]);
                h.radar.show("");
            }
        },
        {
            // With motion on, a Bluetooth member's planet flies to the radar's card. The
            // flown hero is a focusBody too, but only a device's own detail card asks for
            // the effects clock and its 16 ms step: once the planet has landed, an open
            // radar must step at the slow rate, or it costs a few per cent of a core for
            // nothing (NAK-29). The scene cannot settle here (a card keeps it awake, so
            // the orbits drift), hence the steps are counted instead
            "then": 100,
            "until": () => !h.view(scene),
            "run": () => {
                SettingsData.reduceMotion = false;
                h.radar.close();
            }
        },
        {
            "then": 100,
            "until": () => {
                const b = scene.focusBody;
                return !!b && b.focused;
            },
            "run": () => h.radar.show(h.headset)
        },
        {
            // The flight and the card's slide are over by then
            "then": 3000,
            "run": () => {}
        },
        {
            "then": 1000,
            "run": () => {
                h.stepsCounted = 0;
                h.counting = true;
            }
        },
        {
            "then": 100,
            "run": () => {
                h.counting = false;
                check("the planet has landed on the open radar, not on a detail card", [h.radar.open, !!scene.focusBody && scene.focusBody.focused, scene.detailOpen], [true, true, false]);
                print("steps in 1 s with the radar open: " + h.stepsCounted);
                check("an open radar steps at the slow rate (the 16 ms one is the detail card's)", [h.stepsCounted > 0, h.stepsCounted < 40], [true, true]);
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
