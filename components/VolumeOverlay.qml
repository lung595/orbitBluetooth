import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "Route.js" as Route
import "DeviceCatalog.js" as Catalog

// The volume pop-up, without opening anything (D252, D258): whenever a
// level of the output in use changes (volume keys, `dms ipc call`, the
// device's own buttons through AVRCP, DMS's slider, another app), a
// VolumePopup shows the two volumes on every screen, as DMS does with its
// OSD. Event-driven: it listens to PipeWire's change signals, nothing polls.
// Hidden, nothing runs: the pop-ups' content is unloaded and the one sound
// feed they share (cava) is stopped.
Item {
    id: root

    required property var route
    required property var prefs

    // "replace" (DMS's OSD place), "bar", "edge" or "off"
    readonly property string mode: prefs.popupMode
    readonly property string size: prefs.popupSize
    readonly property int fps: prefs.scopeFps
    readonly property bool reduceMotion: prefs.reduceMotion

    // The Bluetooth device in use, or null for any other output (sound
    // card, HDMI): then only this PC's half circle shows (D258)
    readonly property var dev: route.current
    readonly property var shown: Route.shownLevels(route.deviceNode(dev), route.pcNode(dev))
    readonly property var deviceAudio: shown.device && shown.device.audio ? shown.device.audio : null
    readonly property var pcAudio: shown.pc && shown.pc.audio ? shown.pc.audio : null

    readonly property real deviceLevel: deviceAudio ? Math.min(1, deviceAudio.volume) : -1
    readonly property real pcLevel: pcAudio ? Math.min(1, pcAudio.volume) : 0
    readonly property bool deviceMuted: deviceAudio ? deviceAudio.muted : false
    readonly property bool pcMuted: pcAudio ? pcAudio.muted : false
    readonly property string deviceIcon: dev ? Route.iconFor(Catalog.resolve(dev.device, prefs.glyphOverrides)) : "speaker"
    readonly property string pcIcon: shown.ownIcon ? deviceIcon : "computer"

    // --- Gestures from a pop-up -------------------------------------------------
    // DMS's own OSD would answer a level we set: keep it quiet a moment, as
    // DMS's slider does
    function _node(part) {
        return part === "device" ? shown.device : shown.pc;
    }
    function setLevel(part, level) {
        const node = _node(part);
        if (!node || !node.audio)
            return;
        SessionData.suppressOSDTemporarily();
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1, level));
    }
    function toggleMute(part) {
        const node = _node(part);
        if (!node || !node.audio)
            return;
        SessionData.suppressOSDTemporarily();
        node.audio.muted = !node.audio.muted;
    }

    // --- When to show -------------------------------------------------------------
    // A new output, or this PC's saved level coming back on its filter, is
    // not the user turning a knob: no pop-up for a moment after the shown
    // levels change
    property double _calmUntil: 0
    onShownChanged: _calmUntil = Date.now() + 1500

    function poke() {
        if (mode === "off" || Date.now() < _calmUntil)
            return;
        // After DMS's own OSD has shown for the same change: showing last
        // makes OSDManager hide DMS's (one OSD per screen)
        Qt.callLater(_showAll);
    }
    function _showAll() {
        const list = popups.instances;
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            // A level set from the pop-up itself: it stays, the clock restarts
            if (SessionData.suppressOSD) {
                if (p.shouldBeVisible)
                    p.resetHideTimer();
            } else {
                p.show();
            }
        }
        _quietIsland();
    }

    // A Dank Island shows the volume itself, without DMS's OSD manager.
    // Its own controller hands the transient volume face back, in memory
    // only (no setting written, D259, D261); an island the user opened
    // on purpose, or showing anything else, is left alone
    function _quietIsland() {
        const hosts = PopoutService.dankIslandRouter?.hosts?.() ?? [];
        for (let i = 0; i < hosts.length; i++) {
            const c = hosts[i]?.islandController;
            if (c && c.activeActivity === "volume" && !c.expanded)
                c.finishTransient();
        }
    }

    Connections {
        target: root.deviceAudio
        function onVolumeChanged() {
            root.poke();
        }
        function onMutedChanged() {
            root.poke();
        }
    }
    Connections {
        target: root.pcAudio
        function onVolumeChanged() {
            root.poke();
        }
        function onMutedChanged() {
            root.poke();
        }
    }

    // --- Pop-ups and their sound ----------------------------------------------------
    // The screens DMS shows its volume on (Settings → OSD), Dank Island
    // screens included: there the island's volume face steps aside (D261)
    readonly property var screens: {
        // Read explicitly so the binding re-runs when a screen or a screen
        // preference changes: getFilteredScreens() hides these reads
        const all = Quickshell.screens;
        const prefs = SettingsData.screenPreferences;
        return SettingsData.getFilteredScreens("osd") || [];
    }

    Variants {
        id: popups
        model: root.mode !== "off" ? root.screens : []

        delegate: VolumePopup {
            overlay: root
        }
    }

    readonly property bool anyShown: {
        const list = popups.instances;
        for (let i = 0; i < list.length; i++)
            if (list[i].shouldBeVisible)
                return true;
        return false;
    }

    // One cava for every screen's pop-up, only while one shows
    readonly property alias feed: soundFeed
    ScopeFeed {
        id: soundFeed
        node: root.dev ? root.dev.sink : Pipewire.defaultAudioSink
        active: root.anyShown && !root.reduceMotion
        fps: root.fps
    }
}
