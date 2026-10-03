import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "Route.js" as Route
import "DeviceCatalog.js" as Catalog

// The volume pop-up, without opening anything (D252, D258): whenever a
// level of the output in use changes (volume keys, `dms ipc call`, the
// device's own buttons through AVRCP, DMS's slider, another app), the two
// volumes show on every screen, as DMS does with its OSD: inside the Dank
// Island where there is one (IslandFace, D263), else in a VolumePopup. Event-driven: it listens to PipeWire's change signals, nothing polls.
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
    readonly property string style: prefs.scopeStyle
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
        const inIsland = _showInIslands();
        const list = popups.instances;
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (inIsland.indexOf(p.modelData) !== -1) {
                if (p.shouldBeVisible)
                    p.hide();
                continue;
            }
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

    // --- Inside the Dank Island (D263) ----------------------------------------------
    // The island has no room for plugins: Orbit finds its volume sheet (the
    // expanded face of the "volume" activity) and adds its face to it, in
    // memory. Where that sheet cannot be found (another DMS version), the
    // island's own volume face is sent home and the pop-up shows instead.
    property var _faces: []

    // The screens the volume showed on inside their island
    function _showInIslands() {
        const done = [];
        const hosts = PopoutService.dankIslandRouter?.hosts?.() ?? [];
        for (let i = 0; i < hosts.length; i++) {
            const host = hosts[i];
            const c = host?.islandController;
            if (!c)
                continue;
            const face = mode === "replace" ? _faceFor(host) : null;
            if (face) {
                if (SessionData.suppressOSD)
                    face.keep();
                else
                    face.open();
                done.push(host.screen);
            } else if (c.activeActivity === "volume" && !c.expanded) {
                // In memory only (no setting written, D259, D261); an island
                // the user opened on purpose is left alone
                c.finishTransient();
            }
        }
        return done;
    }

    function _faceFor(host) {
        const sheet = _volumeSheet(host);
        if (!sheet)
            return null;
        const kept = [];
        let face = null;
        for (let i = 0; i < _faces.length; i++) {
            const f = _faces[i];
            // A screen gone takes its island, and the face in it, along
            if (!f)
                continue;
            kept.push(f);
            if (f.parent === sheet)
                face = f;
        }
        if (!face) {
            face = faceComponent.createObject(sheet, {
                "overlay": root,
                "controller": host.islandController
            });
            if (face)
                kept.push(face);
        }
        _faces = kept;
        return face;
    }

    // The island's content host, then its "volume" expanded face: a Loader
    // holding DMS's system sheet (the compact face has a slot position)
    function _volumeSheet(host) {
        const content = _find(host.contentItem, o => o.systemExpandedComponent !== undefined && o.renderedActivity !== undefined, 0);
        if (!content)
            return null;
        const kids = content.children;
        for (let i = 0; i < kids.length; i++) {
            const k = kids[i];
            if (k.activity === "volume" && k.sourceComponent === content.systemExpandedComponent && k.alongPos === undefined)
                return k;
        }
        return null;
    }
    function _find(item, test, depth) {
        if (!item || depth > 8)
            return null;
        if (test(item))
            return item;
        const kids = item.children || [];
        for (let i = 0; i < kids.length; i++) {
            const hit = _find(kids[i], test, depth + 1);
            if (hit)
                return hit;
        }
        return null;
    }

    Component {
        id: faceComponent
        IslandFace {}
    }

    // How many island faces show: the sound feed runs only while one does
    property int _islandCount: 0
    property var _islandOpen: []
    function islandShown(face, on) {
        const list = _islandOpen.filter(f => f && f !== face);
        if (on)
            list.push(face);
        _islandOpen = list;
        _islandCount = list.length;
    }

    // Unloaded: the faces go, and an island left grown by Orbit shrinks back
    // (destroying is fine here, creating is not: P130)
    Component.onDestruction: {
        for (let i = 0; i < _faces.length; i++) {
            const f = _faces[i];
            if (!f)
                continue;
            f.close();
            f.destroy();
        }
        _faces = [];
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
    // screens included: a pop-up there only shows if the island cannot
    // hold Orbit's face (D261, D263)
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
        if (_islandCount > 0)
            return true;
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
        active: root.anyShown && !root.reduceMotion && root.style !== "none"
        fps: root.fps
    }
}
