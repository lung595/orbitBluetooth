import QtQuick
import qs.Common
import qs.Services
import "Audiophile.js" as Audiophile
import "Polar.js" as Polar
import "Route.js" as Route
import "../device/DeviceCatalog.js" as Catalog

// The two volumes of one output (D249) and the picture of its sound, as
// ScopeScreen reads them: the device's own level and this PC's, with what
// a gesture on the scope does. The base of VolumeOverlay (the output in
// use) and CardVolume (the device on the detail card). A device with no
// level of its own, or an output that is not Bluetooth, has this PC's
// level only (deviceLevel -1).
Item {
    id: levels

    // The daemon's AudioRoute (null while it is not up)
    property var route: null
    property var prefs: null
    // The Bluetooth device (an AudioRoute entry), or null for any other output
    property var dev: null

    readonly property var shown: route ? Route.shownLevels(route.deviceNode(dev), route.pcNode(dev)) : ({})
    readonly property var deviceAudio: shown.device && shown.device.audio ? shown.device.audio : null
    readonly property var pcAudio: shown.pc && shown.pc.audio ? shown.pc.audio : null

    readonly property real deviceLevel: deviceAudio ? Math.min(1, deviceAudio.volume) : -1
    readonly property real pcLevel: pcAudio ? Math.min(1, pcAudio.volume) : 0
    readonly property bool deviceMuted: deviceAudio ? deviceAudio.muted : false
    readonly property bool pcMuted: pcAudio ? pcAudio.muted : false
    readonly property string deviceIcon: dev ? Route.iconFor(Catalog.resolve(dev.device, prefs ? prefs.glyphOverrides : ({}))) : "speaker"
    readonly property string pcIcon: shown.ownIcon ? deviceIcon : "computer"
    // How loud it is heard: the device's level times this PC's (the
    // vectorscope's picture is drawn that big)
    readonly property real heardLevel: Polar.heardLevel(deviceLevel, pcLevel, deviceMuted, pcMuted)
    // The device's name as the user sees it in Orbit (shown, never logged)
    readonly property string deviceName: dev ? Catalog.deviceName(dev.device) : ""

    readonly property string style: prefs ? prefs.scopeStyle : "points"
    readonly property int fps: prefs ? prefs.scopeFps : 30
    readonly property bool reduceMotion: prefs ? prefs.reduceMotion : false

    // A gesture moved a level (CardVolume plays its tick on it)
    signal levelMoved(real before, real after)

    // --- The sound's picture -----------------------------------------------------
    // One cava and one picture for every screen that shows them, only while
    // someone looks (`listening`, set by the caller): nothing runs at rest
    property bool listening: false
    // The PipeWire sink whose sound is shown
    property var soundNode: null
    ScopeFeed {
        id: soundFeed
        node: levels.soundNode
        active: levels.listening && !levels.reduceMotion && levels.style !== "none"
        fps: levels.fps
    }
    readonly property alias picture: soundPicture
    ScopeModel {
        id: soundPicture
        feed: soundFeed
        style: Polar.styleOf(levels.style)
        fps: levels.fps
        gain: levels.heardLevel
    }

    // --- What the output is (D260) ---------------------------------------------------
    // Read only while someone looks and some fact is chosen; the line for
    // the card or pop-up, the rows for the unfolded detail
    readonly property var _sink: dev ? dev.sink : (route ? route.pcNode(null) : null)
    readonly property bool _wantsFacts: prefs ? (Object.values(prefs.factsLine).includes(true) || Object.values(prefs.factsMore).includes(true)) : false
    // Someone looks at the output (the card is on screen, the pop-up shows)
    property bool looking: listening
    AudioFacts {
        id: audioFacts
        active: levels.looking && levels._wantsFacts
        sink: levels._sink ? levels._sink.name : ""
        pcSink: levels.dev && levels.dev.pc ? levels.dev.pc.name : ""
    }
    // The details are unfolded (one state for every screen that shows them)
    property bool unfolded: false
    AudioGraph {
        id: audioGraph
        readonly property var wanted: levels.prefs ? Audiophile.needs(levels.prefs.factsLine, levels.prefs.factsMore, levels.unfolded) : ({})
        wantDump: levels.looking && !!wanted.dump
        wantTop: levels.looking && !!wanted.top
        sink: audioFacts.sink
    }
    // The output's facts with what the graph adds
    readonly property var _facts: Audiophile.merge(audioFacts.facts, audioGraph.facts)
    readonly property string factsLine: prefs ? Audiophile.line(_facts, prefs.factsLine, audioFacts.pcFacts) : ""
    readonly property var factsRows: prefs ? Audiophile.rows(_facts, prefs.factsMore, audioFacts.pcFacts) : []
    function refreshFacts() {
        audioFacts.refresh();
        audioGraph.refresh();
    }

    // --- Gestures ----------------------------------------------------------------
    // DMS's own OSD would answer a level we set: keep it quiet a moment, as
    // DMS's slider does
    function _node(part) {
        return part === "device" ? shown.device : shown.pc;
    }
    function setLevel(part, level) {
        const node = _node(part);
        if (!node || !node.audio)
            return;
        const before = node.audio.volume;
        SessionData.suppressOSDTemporarily();
        node.audio.muted = false;
        node.audio.volume = Math.max(0, Math.min(1, level));
        levelMoved(before, node.audio.volume);
    }
    // One wheel notch over the scope: a smart step, as the keys
    function stepLevel(part, dir) {
        const node = _node(part);
        if (!node || !node.audio)
            return;
        const before = node.audio.volume;
        SessionData.suppressOSDTemporarily();
        route.stepNode(node, dir);
        levelMoved(before, node.audio.volume);
    }
    function toggleMute(part) {
        const node = _node(part);
        if (!node || !node.audio)
            return;
        SessionData.suppressOSDTemporarily();
        node.audio.muted = !node.audio.muted;
    }
}
