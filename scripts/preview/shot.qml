import QtQuick
import QtQuick.Window
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
//        btblocked (Turn on did nothing: note), noadapter
Window {
    id: win
    readonly property var args: Qt.application.arguments
    // Suffixes: "-light" renders with a light theme's accent colors,
    // "-bright" puts the desktop shots on a pale, busy wallpaper (the
    // hardest case for label contrast), "-none" disconnects every device,
    // "-fit" sizes the window like the bar popout (grows to the open card),
    // "-cc" like the Control Center tile (same, from a smaller minimum),
    // "-follow" gives the headset no level of its own (no absolute volume),
    // "-fold" starts the card's volumes folded, as in the menus, and
    // "-unfold" shows them unfolded there, "-facts" opens the audio details
    readonly property string rawMode: args[args.length - 2]
    readonly property var parts: rawMode.split("-")
    readonly property bool bright: parts.indexOf("bright") > 0
    readonly property bool light: parts.indexOf("light") > 0
    readonly property bool none: parts.indexOf("none") > 0
    readonly property bool cc: parts.indexOf("cc") > 0
    readonly property bool fit: parts.indexOf("fit") > 0 || cc
    readonly property bool follow: parts.indexOf("follow") > 0
    readonly property bool fold: parts.indexOf("fold") > 0 || unfold
    readonly property bool unfold: parts.indexOf("unfold") > 0
    readonly property bool facts: parts.indexOf("facts") > 0
    readonly property string mode: parts[0]
    readonly property string out: args[args.length - 1]
    readonly property bool glass: mode.startsWith("desktop")
    // Control Center sized shots for the black hole, menu and comet
    readonly property bool compact: ["buds", "budsdock", "hole", "holetess", "hiddencard", "hiddenempty", "connecting", "menu", "feed"].indexOf(mode) >= 0
    width: glass ? 760 : (mode === "zoom" ? 900 : compact ? 540 : 560)
    height: fit ? Math.max(cc ? 314 : 440, Math.ceil(scene.focusFitHeight)) + 40 : glass ? 560 : (mode === "zoom" ? 700 : mode.startsWith("buds") ? 520 : mode === "ancfocus" ? 540 : compact ? 354 : 480)
    visible: true
    color: "#101114"

    readonly property double t: Date.now()

    readonly property var devices: Devices.list(none)

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
        if (mode !== "hiddenempty")
            SettingsData.pluginSettings = Object.assign({}, SettingsData.pluginSettings, {
                "hiddenDevices": {
                    "3C:8D:20:54:AB:12": "Keychron K3",
                    "E8:07:BF:6A:19:D4": "JBL Flip 6"
                },
                "holeStyle": mode === "holetess" ? "tesseract" : "blackhole",
                "desktopBackdrop": bright ? 50 : 72
            });
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
    }

    // The scene object a shot acts on, by its Bluetooth address
    function bodyOf(address) {
        return scene.world.children.find(c => c.address === address);
    }

    // Puts the scene in the state the mode shows (opens a card, a menu, a drag…)
    function stage() {
        if (mode.startsWith("buds")) {
            const b = bodyOf("00:11:22:33:44:55");
            if (b)
                scene.focusOn(b);
        } else if (mode.endsWith("focus")) {
            const b = bodyOf("02:00:00:00:10:06");
            if (b)
                scene.focusOn(b);
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
            const b = bodyOf("D4:1A:88:10:5B:77");
            if (b) {
                scene.beginDrag(b, Qt.point(b.px, b.py));
                scene.updateDrag(Qt.point(scene.holeX + 26, scene.holeY - 22));
            }
        }
    }

    // How long the staged scene needs to settle before the capture (ms)
    function settleTime() {
        if (mode.startsWith("buds"))
            return 2600;
        if (mode === "volumefocus")
            return 1760;
        if (mode.endsWith("focus") || mode.startsWith("hidden"))
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
                line.expanded = win.facts;
        }
    }
    Timer {
        id: grabTimer
        onTriggered: {
            // Where the drifting black hole ended up (to crop close-ups)
            console.info("hole", scene.holeX + frame.x, scene.holeY + frame.y);
            win.contentItem.grabToImage(r => {
                r.saveToFile(win.out);
                Qt.quit();
            });
        }
    }
}
