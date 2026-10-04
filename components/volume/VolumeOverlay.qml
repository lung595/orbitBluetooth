import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "Keys.js" as Keys

// The volume pop-up, without opening anything (D252, D258): whenever a
// level of the output in use changes (volume keys, `dms ipc call`, the
// device's own buttons through AVRCP, DMS's slider, another app), the two
// volumes show on every screen, in place of DMS's OSD, which is switched off
// (DmsOsdOff, D273): inside the Dank Island where there is one (IslandFace,
// D263), else in a VolumePopup. Event-driven: it listens to PipeWire's
// change signals, nothing polls.
// Hidden, nothing runs: the pop-ups' content is unloaded and the one sound
// feed they share (cava) is stopped.
TwoLevels {
    id: root

    // VolumeKeys: the volume keys and Orbit's smart steps (D265)
    property var keys: null

    // "replace" (DMS's OSD place), "bar", "edge" or "off"
    readonly property string mode: prefs.popupMode
    readonly property string size: prefs.popupSize

    // One pop-up on screen, and it is Orbit's: DMS's volume OSD stays off
    // unless the user turned Orbit's pop-up off (D273)
    DmsOsdOff {
        settings: SettingsData
        active: root.mode !== "off"
    }

    // The Bluetooth device in use, or null for any other output (sound
    // card, HDMI): then only this PC's half circle shows (D258)
    dev: route.current

    // --- The volume keys, offered once (D265) ------------------------------------------
    // The first time the scope shows, a one-line note offers to bind the
    // volume keys to Orbit. Nothing changes without the user's click, and
    // the note never comes back.
    property string keysNote: ""
    readonly property var note: Keys.note(keysNote)
    property bool _offered: false
    function _offerKeys() {
        if (!keys || prefs.keysOffered || _offered)
            return;
        _offered = true;
        keys.refresh(() => {
            const k = root.keys.keys;
            if (k === "dms")
                root.keysNote = "offer";
            else if (k === "unsupported")
                root.keysNote = "manual";
            // Unreadable: try again next session
            if (k !== "unknown")
                root.prefs.set("keysOffered", true);
        });
    }
    function noteAction() {
        if (keysNote === "offer")
            keys.enable();
        else if (keysNote === "done")
            keys.disable();
    }
    Connections {
        target: root.keys
        function onKeysChanged() {
            const k = root.keys.keys;
            if (k === "orbit" && (root.keysNote === "offer" || root.keysNote === "undone"))
                root.keysNote = "done";
            else if (k === "dms" && root.keysNote === "done")
                root.keysNote = "undone";
        }
        function onFailedChanged() {
            if (root.keys.failed && root.keysNote !== "")
                root.keysNote = "failed";
        }
    }
    onAnyShownChanged: if (!anyShown)
        keysNote = ""

    // --- When to show -------------------------------------------------------------
    // A new output, or this PC's saved level coming back on its filter, is
    // not the user turning a knob: no pop-up for a moment after the shown
    // levels change
    property double _calmUntil: 0
    onShownChanged: _calmUntil = Date.now() + 1500

    function poke() {
        if (mode === "off" || Date.now() < _calmUntil)
            return;
        _settled = false;
        settle.restart();
        // Once per turn of the event loop, however many levels changed in it
        Qt.callLater(_showAll);
    }
    // Starting cava costs about as much as the whole burst of keys (a fixed
    // 0.4 s of CPU, measured, P142): its picture waits until the keys stop
    property bool _settled: true
    Timer {
        id: settle
        interval: 700
        onTriggered: root._settled = true
    }
    function _showAll() {
        _offerKeys();
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
                // DMS's OSD is off, but its switch may be turned back on
                // meanwhile: the island's own volume face is sent home. In
                // memory only (D259, D261); an island the user opened on
                // purpose is left alone
                c.finishTransient();
            }
        }
        return done;
    }

    function _faceFor(host) {
        // A screen gone takes its island, and the face in it, along
        const kept = _faces.filter(f => !!f && !!f.parent);
        // The face already made for this island: no walk through its items
        // on every volume step
        let face = kept.find(f => f.controller === host.islandController) || null;
        if (!face) {
            const sheet = _volumeSheet(host);
            if (!sheet)
                return null;
            face = faceComponent.createObject(sheet, {
                "overlay": root,
                "controller": host.islandController,
                "host": host
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

    // Any level or mute that moves, the device's, this PC's or a member's,
    // raises the pop-up
    Instantiator {
        model: root.audios
        delegate: Connections {
            required property var modelData
            target: modelData
            function onVolumeChanged() {
                root.poke();
            }
            function onMutedChanged() {
                root.poke();
            }
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
    soundNode: dev ? dev.sink : Pipewire.defaultAudioSink
    listening: anyShown && _settled
}
