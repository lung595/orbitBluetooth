import QtQuick
import qs.Common
import qs.Services
import "Audiophile.js" as Audiophile
import "Members.js" as Members
import "Polar.js" as Polar
import "Route.js" as Route
import "../device/DeviceCatalog.js" as Catalog
import "../together/Member.js" as Member
import "../together/Wired.js" as Wired

// The volumes of one output (D249) and the picture of its sound, as
// ScopeScreen reads them: the device's own level and this PC's, with what
// a gesture on the scope does. The base of VolumeOverlay (the output in
// use) and CardVolume (the device on the detail card). A device with no
// level of its own, or an output that is not Bluetooth, has this PC's
// level only (deviceLevel -1).
// Listening together (D254, D277): when `dev` is one of the outputs sharing
// the sound, `members` lists them all, in the order they joined (two to
// four), each with its own level, and this PC's level is the shared one the
// copies are taken from (`split`). A part is named "device" (the device's
// own), "m0" to "m3" (a member, as in `members`) or "pc".
Item {
    id: levels

    // The daemon's AudioRoute (null while it is not up)
    property var route: null
    property var prefs: null
    // The Bluetooth device (an AudioRoute entry), or null for any other output
    property var dev: null

    readonly property var shown: route ? Route.shownLevels(route.deviceNode(dev), route.pcNode(dev)) : ({})
    readonly property var together: route ? route.together : null
    // The outputs sharing the sound when `dev` is one of them, else none
    readonly property var memberAddresses: {
        const list = together ? together.members : [];
        return dev && list.length >= 2 && list.indexOf(dev.address) >= 0 ? list : [];
    }
    readonly property bool split: memberAddresses.length >= 2
    // The nodes holding each level (a member's: see _node)
    readonly property var _deviceNode: split ? null : shown.device || null
    readonly property var _pcNode: split ? together.sharedNode : shown.pc || null
    readonly property var _memberNodes: memberAddresses.map(a => together.memberNode(a))
    function _audioOf(node) {
        return node && node.audio ? node.audio : null;
    }
    readonly property var deviceAudio: _audioOf(_deviceNode)
    readonly property var pcAudio: _audioOf(_pcNode)
    // Every audio whose level or mute a gesture or a key can move, for the
    // caller to watch
    readonly property var audios: [deviceAudio, pcAudio].concat(_memberNodes.map(_audioOf)).filter(a => !!a)

    function _iconOf(d) {
        return d ? Route.iconFor(Catalog.resolve(d.device, prefs ? prefs.glyphOverrides : ({}))) : "speaker";
    }
    // The outputs listening together, left to right ([] when there are fewer
    // than two): { part, address, level, muted, icon, label }. A wired output
    // is drawn by the kind of its connection (usb, hdmi, analog), never by a
    // Bluetooth picture, and named as the session names it.
    readonly property var members: memberAddresses.map((a, i) => {
        const audio = _audioOf(_memberNodes[i]);
        const d = route.known(a);
        const wired = Member.isWired(a);
        return {
            "part": Polar.partOf(i, memberAddresses.length),
            "address": a,
            "target": route.target === a,
            "level": audio ? Math.min(1, audio.volume) : 0,
            "muted": audio ? audio.muted : false,
            "icon": wired ? Wired.iconOf(Wired.kindOfNode(_memberNodes[i])) : _iconOf(d),
            "label": wired ? together.nameOf(a) : d ? Catalog.deviceName(d.device) : ""
        };
    })

    // The device's own level (-1: it has none, or the outputs are shared)
    readonly property real deviceLevel: deviceAudio ? Math.min(1, deviceAudio.volume) : -1
    readonly property real pcLevel: pcAudio ? Math.min(1, pcAudio.volume) : 0
    readonly property bool deviceMuted: deviceAudio ? deviceAudio.muted : false
    readonly property bool pcMuted: pcAudio ? pcAudio.muted : false
    readonly property string deviceIcon: _iconOf(dev)
    readonly property string pcIcon: shown.ownIcon && !split ? deviceIcon : "computer"
    // How loud it is heard: the device's level times this PC's (the
    // vectorscope's picture is drawn that big); the loudest member's when split
    readonly property real heardLevel: split ? Members.heardOf(members, pcLevel, pcMuted) : Polar.heardLevel(deviceLevel, pcLevel, deviceMuted, pcMuted)
    // The device's name as the user sees it in Orbit (shown, never logged)
    readonly property string deviceName: dev ? Catalog.deviceName(dev.device) : ""

    readonly property string style: prefs ? prefs.scopeStyle : "points"
    readonly property int fps: prefs ? prefs.scopeFps : 30
    readonly property bool reduceMotion: prefs ? prefs.reduceMotion : false

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
    property alias unfolded: visit.unfolded
    UnfoldedVisit {
        id: visit
    }
    function scopeShown(on) {
        visit.screenShown(on);
    }
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
    // The node of a part. Writing goes through the route, so a level of the
    // shared PC half reaches every member's copy (Route.levelNodes).
    // DMS's own OSD would answer a level we set: keep it quiet a moment, as
    // DMS's slider does
    function _node(part) {
        if (part === "pc")
            return _pcNode;
        if (part === "device")
            return _deviceNode;
        const i = Polar.indexOf(part);
        return i >= 0 && i < _memberNodes.length ? _memberNodes[i] : null;
    }
    // The keys follow the member whose arc was touched last (AudioRoute.touched);
    // this PC's level, or the one device's, is not a member's
    function _touch(part) {
        const i = split ? Polar.indexOf(part) : -1;
        route.touch(i >= 0 ? memberAddresses[i] : "");
    }
    function setLevel(part, level) {
        const node = _node(part);
        if (!node || !node.audio)
            return;
        SessionData.suppressOSDTemporarily();
        _touch(part);
        route.writeLevel(node, Math.max(0, Math.min(1, level)));
    }
    // One wheel notch over the scope: a smart step, as the keys
    function stepLevel(part, dir) {
        const node = _node(part);
        if (!node || !node.audio)
            return;
        SessionData.suppressOSDTemporarily();
        _touch(part);
        route.stepNode(node, dir);
    }
    function toggleMute(part) {
        const node = _node(part);
        if (!node || !node.audio)
            return;
        SessionData.suppressOSDTemporarily();
        route.writeMuted(node, !node.audio.muted);
    }
}
