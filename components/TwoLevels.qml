import QtQuick
import qs.Common
import qs.Services
import "Route.js" as Route
import "DeviceCatalog.js" as Catalog

// The two volumes of one output (D249), as ScopeScreen reads them: the
// device's own level and this PC's, with what a gesture on the scope does.
// The base of VolumeOverlay (the output in use) and CardVolume (the device
// on the detail card). A device with no level of its own, or an output
// that is not Bluetooth, has this PC's level only (deviceLevel -1).
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
    readonly property real heardLevel: deviceLevel >= 0 ? (deviceMuted || pcMuted ? 0 : deviceLevel * pcLevel) : (pcMuted ? 0 : pcLevel)
    // The device's name as the user sees it in Orbit (shown, never logged)
    readonly property string deviceName: dev ? Catalog.deviceName(dev.device) : ""

    readonly property string style: prefs ? prefs.scopeStyle : "points"
    readonly property int fps: prefs ? prefs.scopeFps : 60
    readonly property bool reduceMotion: prefs ? prefs.reduceMotion : false

    // A gesture moved a level (CardVolume plays its tick on it)
    signal levelMoved(real before, real after)

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
