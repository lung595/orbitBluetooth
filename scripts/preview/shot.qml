import QtQuick
import QtQuick.Window
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "../../components/scene"
import "../../components/common/Guide.js" as Guide
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Offscreen renders for the README, with mock devices and services.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports shot.qml -- <mode> <out.png>
// Modes: orbit, zoom, orbitfocus, volumefocus (the card with its two volumes), desktop, desktopfocus, ancfocus,
//        buds, budsdock, hole, holetess, hiddencard, hiddenempty, connecting, menu, feed,
//        btblocked (Turn on did nothing: note), noadapter,
//        together2, together3, together4 (the headset and 1 to 3 speakers listen
//        together: the source takes the center), togetherback (the host was
//        clicked: it is back at the center and the group has stepped back)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    // Suffixes: "-light" renders with a light theme's accent colors,
    // "-bright" puts the desktop shots on a pale, busy wallpaper (the
    // hardest case for label contrast), "-none" disconnects every device,
    // "-fit" sizes the window like the bar popout (grows to the open card),
    // "-cc" like the Control Center tile (same, from a smaller minimum),
    // "-silent" stops the made-up sound (the beams of a group do not pulse),
    // "-reduce" turns Reduce motion on, "-glass" shows any shot as the desktop
    // widget (the veil over a wallpaper), "-bench" takes no picture: once the
    // scene has settled it counts the frames drawn over 6 s and quits
    // (see depth-bench.sh), "-feed" carries a device to the black hole in the
    // "together" shots (the hole is lit up while the sky is out of focus),
    // "-chooser" opens the group chooser from a device outside the group (the hidden
    // outputs are in its Hidden section, which opens by itself the first time),
    // "-sun90" puts the host's system at that angle of its path in the "together"
    // shots (90 near and in front, 270 far and behind, 0 right, 180 left),
    // "-follow" gives the headset no level of its own (no absolute volume),
    // "-fold" starts the card's volumes folded, as in the menus, and
    // "-unfold" shows them unfolded there, "-facts" opens the audio details,
    // "-loop" takes no picture: once staged, the mode's card closes and opens
    // again every 1.5 s until the process is stopped (CPU bench of the action),
    // "-hold" takes no picture and stays staged until stopped (CPU bench at rest),
    // "-empty" starts with nothing hidden, and "-churn" (implies "-hold") hides
    // and brings back an output every second (CPU bench of the Hidden section)
    readonly property string rawMode: args[args.length - 2]
    readonly property var parts: rawMode.split("-")
    readonly property bool bright: parts.indexOf("bright") > 0
    readonly property bool light: parts.indexOf("light") > 0
    readonly property bool none: parts.indexOf("none") > 0
    readonly property bool cc: parts.indexOf("cc") > 0
    readonly property bool fit: parts.indexOf("fit") > 0 || cc
    readonly property bool follow: parts.indexOf("follow") > 0
    readonly property bool silent: parts.indexOf("silent") > 0
    readonly property bool reduce: parts.indexOf("reduce") > 0
    readonly property bool bench: parts.indexOf("bench") > 0
    readonly property bool loop: parts.indexOf("loop") > 0
    readonly property bool feed: parts.indexOf("feed") > 0
    readonly property bool chooser: parts.indexOf("chooser") > 0
    readonly property bool churn: parts.indexOf("churn") > 0
    readonly property bool hold: churn || parts.indexOf("hold") > 0
    readonly property bool empty: parts.indexOf("empty") > 0
    readonly property var sunAngle: parts.find(p => /^sun\d+$/.test(p))
    // "-level35" sets the group's general volume before the group forms (the
    // gauge shows no reading), "-read35" sets it while the picture is taken (the
    // gauge writes its level out), "-muted" mutes the group the same way
    readonly property var levelPart: parts.find(p => /^level\d+$/.test(p))
    readonly property var readPart: parts.find(p => /^read\d+$/.test(p))
    readonly property bool muted: parts.indexOf("muted") > 0
    // Speakers that listen together with the headset in the "together" shots
    readonly property int outputs: mode.startsWith("together") && mode !== "togetherback" ? Number(mode.slice(8)) - 1 : mode === "togetherback" ? 2 : 0
    readonly property bool fold: parts.indexOf("fold") > 0 || unfold
    readonly property bool unfold: parts.indexOf("unfold") > 0
    readonly property bool facts: parts.indexOf("facts") > 0
    readonly property string mode: parts[0]
    readonly property string out: args[args.length - 1]
    readonly property bool glass: mode.startsWith("desktop") || parts.indexOf("glass") > 0
    // Control Center sized shots for the black hole, menu and comet
    readonly property bool compact: ["buds", "budsdock", "hole", "holetess", "hiddencard", "hiddenempty", "connecting", "menu", "feed"].indexOf(mode) >= 0
    width: glass ? 760 : (mode === "zoom" ? 900 : compact ? 540 : 560)
    height: fit ? Math.max(cc ? 314 : 440, Math.ceil(scene.focusFitHeight)) + 40 : glass ? 560 : (mode === "zoom" ? 700 : mode.startsWith("buds") ? 520 : mode === "ancfocus" ? 540 : compact ? 354 : 480)
    visible: true
    color: "#101114"

    readonly property double t: Date.now()

    readonly property var devices: Devices.list(none, outputs)

    Component.onCompleted: {
        if (light) {
            // Accent colors like DMS generates for a light theme
            Theme.isLightMode = true;
            Theme.primary = "#4B6818";
            Theme.primaryText = "#FFFFFF";
            Theme.tertiary = "#386A60";
            Theme.error = "#BA1A1A";
            Theme.errorText = "#FFFFFF";
        }
        // Two made-up devices already swallowed by the black hole
        if (mode !== "hiddenempty" && !empty)
            SettingsData.pluginSettings = Object.assign({}, SettingsData.pluginSettings, {
                "hiddenDevices": {
                    "3C:8D:20:54:AB:12": "Keychron K3",
                    "E8:07:BF:6A:19:D4": "JBL Flip 6"
                },
                "holeStyle": mode === "holetess" ? "tesseract" : "blackhole",
                "desktopBackdrop": bright ? 50 : 72
            });
        SettingsData.reduceMotion = reduce;
        Pipewire.playing = !silent;
        BluetoothService.discovering = mode === "orbit";
        // btblocked: "Turn on" pressed, nothing changed (note shown);
        // noadapter: no adapter at all
        BluetoothService.available = mode !== "noadapter";
        BluetoothService.enabled = mode !== "btblocked" && mode !== "noadapter";
        PluginService.globalVars = State.globals(mode, t);
    }

    Wallpaper {
        anchors.fill: parent
        visible: win.glass
        bright: win.bright
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: win.glass ? 60 : 20
        radius: 16
        color: win.glass ? "transparent" : "#07080c"
        clip: !win.glass

        OrbitScene {
            id: scene
            anchors.fill: parent
            glass: win.glass
            active: true
            autoScan: false
            previewDevices: win.devices
            audioRoute: fakeRoute
            foldVolume: win.fold
            volumeUnfolded: win.unfold
            cornerRadius: win.glass ? 0 : 16
        }
    }

    FakeRoute {
        id: fakeRoute
        focusDevice: scene.focusBody ? scene.focusBody.device : null
        follow: win.follow
        sharing: win.outputs > 0 ? ["02:00:00:00:10:06", "02:00:00:00:20:01", "02:00:00:00:20:02", "02:00:00:00:20:03"].slice(0, win.outputs + 1) : []
    }

    // The scene object a shot acts on, by its Bluetooth address
    function bodyOf(address) {
        return scene.world.children.find(c => c.address === address);
    }

    // The group's volume (the gauge): quiet before the group forms, or heard just before the picture
    Timer {
        running: !!win.levelPart
        interval: 1
        onTriggered: fakeRoute.writeLevel(fakeRoute.shared, Number(win.levelPart.slice(5)) / 100)
    }
    Timer {
        id: reader
        interval: 900
        onTriggered: {
            if (win.readPart)
                fakeRoute.writeLevel(fakeRoute.shared, Number(win.readPart.slice(4)) / 100);
            if (win.muted)
                fakeRoute.writeMuted(fakeRoute.shared, true);
        }
    }

    // Puts the scene in the state the mode shows (opens a card, a menu, a drag…)
    function stage() {
        reader.start();
        if (mode.startsWith("buds")) {
            const b = bodyOf("00:11:22:33:44:55");
            if (b)
                scene.focusOn(b);
        } else if (mode.endsWith("focus")) {
            const b = bodyOf("02:00:00:00:10:06");
            if (b)
                scene.focusOn(b);
        } else if (mode === "togetherback") {
            scene.centre.recall();
        } else if (mode.startsWith("together") && chooser) {
            scene.openGroupChooser(bodyOf("D4:1A:88:10:5B:77"), Qt.point(80, 80));
        } else if (mode.startsWith("together") && feed) {
            carryToHole();
        } else if (mode.startsWith("together") && sunAngle) {
            scene.centre.sunPhase = Number(sunAngle.slice(3)) * Math.PI / 180;
        } else if (mode === "hiddencard" || mode === "hiddenempty") {
            scene.openHidden();
        } else if (mode === "btblocked") {
            scene.explain(Guide.blockedNote());
        } else if (mode === "connecting") {
            const b = bodyOf("6C:4A:85:9E:03:21");
            if (b)
                b.phase = "connecting";
        } else if (mode === "menu") {
            const b = bodyOf("02:00:00:00:10:06");
            if (b)
                scene.openMenu(b, Qt.point(b.px + 14, b.py + 6));
        } else if (mode === "feed") {
            carryToHole();
        }
    }

    // A device is carried to the black hole, which lights up for it
    function carryToHole() {
        const b = bodyOf("D4:1A:88:10:5B:77");
        if (b) {
            scene.beginDrag(b, Qt.point(b.px, b.py));
            scene.updateDrag(Qt.point(scene.holeX + 26, scene.holeY - 22));
        }
    }

    // How long the staged scene needs to settle before the capture (ms)
    function settleTime() {
        // The audio details: after the made-up graph answer (4000 + 1200 ms)
        if (facts)
            return 6200;
        if (mode.startsWith("buds"))
            return 2600;
        if (mode === "volumefocus")
            return 1760;
        if (mode.endsWith("focus") || mode.startsWith("hidden"))
            return 1800;
        if (mode.startsWith("together"))
            return 1800;
        if (mode === "connecting")
            return 700;
        if (mode === "feed" || mode === "menu" || mode === "btblocked")
            return 900;
        return 50;
    }

    // An item of the open card by its objectName, wherever it sits in the tree
    function findNamed(item, name) {
        if (item.objectName === name)
            return item;
        for (const c of item.children) {
            const r = findNamed(c, name);
            if (r)
                return r;
        }
        return null;
    }

    Timer {
        interval: win.mode === "zoom" ? 14000 : 2600
        running: true
        onTriggered: {
            win.stage();
            grabTimer.interval = win.settleTime();
            grabTimer.start();
        }
    }
    // Focused shots: once the card is up, a made-up sound fills its scope
    Timer {
        running: win.mode.endsWith("focus")
        interval: 2600 + 1400
        onTriggered: {
            const scope = win.findNamed(win.contentItem, "cardScope");
            if (scope && scope.visible)
                scope.simulate(State.soundFrame, 0.7);
            // What PipeWire would say of the headset and this PC's filter
            // (the preview runs no command)
            const facts = win.findNamed(win.contentItem, "audioFacts");
            if (facts)
                facts._all = State.fakeSinks;
            const line = win.findNamed(win.contentItem, "factsLine");
            if (line)
                line.source.unfolded = win.facts;
            graphTimer.start();
        }
    }
    // The graph's answer, made up, once the real (read-only) commands that
    // unfolding started have ended: they would replace it
    Timer {
        id: graphTimer
        interval: 1200
        onTriggered: {
            const graph = win.findNamed(win.contentItem, "audioGraph");
            if (graph) {
                graph._dumped = State.fakeDump;
                graph._topped = State.fakeTop;
            }
        }
    }
    // Bench: the frames the window swapped, counted from the start of the window
    readonly property int benchMs: 6000
    property int frames: 0
    Connections {
        target: win
        function onFrameSwapped() {
            win.frames++;
        }
    }
    Timer {
        id: benchEnd
        interval: win.benchMs
        onTriggered: {
            print("bench", win.mode, "frames", win.frames, "in", win.benchMs, "ms");
            Qt.quit();
        }
    }
    // "-loop": the card the mode stages closes, then opens again, forever
    Timer {
        id: cardLoop
        interval: 1500
        repeat: true
        onTriggered: scene.cardOpen ? scene.clearFocus() : win.stage()
    }
    // "-churn": a made-up output goes to the black hole, then comes back, each second
    Timer {
        id: churnTimer
        interval: 1000
        repeat: true
        onTriggered: {
            const id = "E8:07:BF:6A:19:D4";
            if (scene.prefs.hiddenDevices[id])
                scene.unhide(id);
            else
                scene.hideById(id, "JBL Flip 6");
        }
    }
    Timer {
        id: grabTimer
        onTriggered: {
            if (win.hold) {
                churnTimer.running = win.churn;
                return;
            }
            if (win.loop) {
                cardLoop.start();
                return;
            }
            if (win.bench) {
                win.frames = 0;
                print("bench start");
                benchEnd.start();
                return;
            }
            // Where the drifting black hole ended up (to crop close-ups)
            console.info("hole", scene.holeX + frame.x, scene.holeY + frame.y);
            win.contentItem.grabToImage(r => {
                r.saveToFile(win.out);
                Qt.quit();
            });
        }
    }
}
