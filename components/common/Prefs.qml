import QtQuick
import qs.Common
import qs.Services
import "../device/BeamStyle.js" as BeamStyle
import "../together/Delay.js" as Delay
import "Hidden.js" as Hidden
import "../volume/Audiophile.js" as Audiophile
import "../volume/Polar.js" as Polar
import "../volume/Steps.js" as Steps
import "../volume/Target.js" as Target

// Reactive view over the plugin's saved settings, shared by every surface.
QtObject {
    id: root

    readonly property string pluginId: "orbitBluetooth"

    property var _data: SettingsData.getPluginSettingsForPlugin(pluginId) || ({})

    function _get(key, def) {
        const v = _data[key];
        return v === undefined || v === null ? def : v;
    }

    // The settings that hold a map change only when their content does: a
    // fresh object on every save (a volume level, a hidden device) would
    // wake every view bound to any of them (P137)
    readonly property var _maps: ["glyphOverrides", "hiddenDevices", "pcLevels", "togetherHabits"]
    function _load() {
        _data = SettingsData.getPluginSettingsForPlugin(pluginId) || ({});
        for (const key of _maps) {
            const next = _get(key, ({}));
            if (JSON.stringify(next) !== JSON.stringify(root[key]))
                root[key] = next;
        }
    }
    Component.onCompleted: _load()

    readonly property bool showUnnamed: _get("showUnnamed", false)
    readonly property bool showLabels: _get("showLabels", true)
    readonly property int maxDevices: parseInt(_get("maxDevices", "8"))
    // Offer to connect a new unpaired device found while scanning
    readonly property bool offerNew: _get("offerNew", true)
    // Settings of features removed after 1.15: the pairing sheet under the
    // bar (and the addresses refused with "Don't offer again"), Orbit OSD,
    // the old way the volume keys were taken, and the launcher's words. The daemon clears them
    // once (null reads as unset)
    readonly property var retiredKeys: ["offerPopup", "offerScan", "offerEvery", "offerMinBattery", "ignoredDevices", "popupMode", "popupSize", "popupScreens", "keysOffered", "keysGivenBack", "launcherWords"]
    readonly property bool retiredSettings: retiredKeys.some(k => _data[k] !== undefined && _data[k] !== null)
    readonly property bool autoScan: _get("autoScan", true)
    // Hover × on connected devices; off by default (drag away or right-click instead)
    readonly property bool quickDisconnect: _get("quickDisconnect", false)
    readonly property int scanSeconds: parseInt(_get("scanSeconds", "45"))
    readonly property bool sounds: _get("sounds", false)
    readonly property real soundVolume: _get("soundVolume", 60) / 100
    readonly property bool shootingStars: _get("shootingStars", true)
    readonly property string starDensity: _get("starDensity", "normal")
    readonly property bool desktopAmbient: _get("desktopAmbient", false)
    readonly property real desktopBackdrop: _get("desktopBackdrop", 72) / 100
    readonly property string hostGlyph: _get("hostGlyph", "auto")
    // While a Listen together session plays, the source takes the center and
    // the other outputs orbit it (off: the scene keeps its usual layout)
    readonly property bool togetherCentre: _get("togetherCentre", true)
    // Listen together: a nudge (ms, -100..100) on the automatic wait of the
    // wired outputs, for what the figures cannot know (a speaker's own delay)
    readonly property int togetherFineDelay: Delay.cleanFine(Number(_get("togetherFineDelay", 0)))
    // The ghost group learns which outputs are listened to together (D299): on
    // by default since it is only hashes, capped and local; off erases it
    readonly property bool learnHabits: _get("learnHabits", true)
    // What it learned: a group of hashed members -> { n: uses, d: day of the last }
    property var togetherHabits: ({})
    readonly property string imageFolder: _get("imageFolder", "")
    property var glyphOverrides: ({})
    readonly property bool ancEnabled: _get("ancEnabled", true)
    readonly property string ancEngine: _get("ancEngine", "demand")
    // Turn conversation awareness off when a headset disconnects or reconnects
    readonly property bool ancChatOff: _get("ancChatOff", true)
    // Pause what plays on a Sony headset when it is taken off, resume it
    // when it is put back (D277). On by default: it only acts on its own
    // pauses, and costs one open control connection per such headset
    readonly property bool wearPause: _get("wearPause", true)
    // Left by "Real device pictures" (removed after 1.15): the daemon erases
    // its old download folder once when this is still on
    readonly property bool oldRealPictures: _get("realPictures", false)
    // Devices swallowed by the black hole: address -> name (the name keeps
    // the list readable when the device is out of range)
    property var hiddenDevices: ({})
    // The group chooser's Hidden section, as the user left it: true (open),
    // false (folded) or null (never chosen: it opens by itself once, D368)
    readonly property var hiddenSectionOpen: _get("hiddenSectionOpen", null)
    // Look of the black hole: "blackhole" (realistic) or "tesseract"
    readonly property string holeStyle: _get("holeStyle", "blackhole")
    // How power flows to a charging device (BeamStyle.STYLES); anything else
    // is the default
    readonly property string chargeBeamStyle: BeamStyle.parse(_get("chargeBeamStyle", BeamStyle.DEFAULT))

    // Two volumes (D249, D255): this PC's level on a virtual sink in front
    // of a device that has its own volume. Off: one level, as before
    readonly property bool separatePc: _get("separatePc", true)
    // This PC's level per device, address -> 0..1 (D256)
    property var pcLevels: ({})
    // The vectorscope's cloud: 60 frames a second ("Smooth") or 30 ("Light")
    readonly property int scopeFps: parseInt(_get("scopeFps", "30")) === 60 ? 60 : 30
    // How the vectorscope draws the sound: "points", "rays", "waves", "none"
    readonly property string scopeStyle: Polar.styleOf(_get("scopeStyle", "points"))

    // Volume steps for up / down (D264): "smart" (a fine step alone,
    // growing while presses come fast) or "fixed" (volumeStep percent)
    readonly property string volumeSteps: _get("volumeSteps", "smart") === "fixed" ? "fixed" : "smart"
    // How fast smart steps grow: "gentle", "balanced" or "fast"
    readonly property string volumeSpeed: Steps.speedOf(_get("volumeSpeed", "balanced"))
    readonly property int volumeStep: Steps.fixedStep(_get("volumeStep", 5))

    // What the volume keys move while a group plays (NAK-258): "follow" the
    // last change, "group" or "device"
    readonly property string groupKeys: Target.groupKeysOf(_get("groupKeys", "follow"))

    // What the output is (D260): which facts show on the card's line
    // (factCard_<key>) and in the unfolded detail (factMore_<key>)
    function _facts(prefix, field) {
        const chosen = {};
        for (const info of Audiophile.INFOS)
            chosen[info.key] = _get(prefix + info.key, info[field]);
        return chosen;
    }
    readonly property var factsLine: _facts("factCard_", "card")
    readonly property var factsMore: _facts("factMore_", "more")

    // The user asked for the volume keys to use Orbit's smart steps; off by
    // default, the keys are DMS's (D265)
    readonly property bool keysOrbit: _get("keysOrbit", false)
    // The keys an older version took by itself were given back, once
    readonly property bool keysReturned: _get("keysReturned", false)

    readonly property bool reduceMotion: SettingsData.reduceMotion

    function set(key, value) {
        PluginService.savePluginData(pluginId, key, value);
    }

    function setGlyphOverride(address, kind) {
        const next = Object.assign({}, glyphOverrides);
        if (!kind || kind === "auto")
            delete next[address];
        else
            next[address] = kind;
        set("glyphOverrides", next);
    }

    function isHidden(address) {
        return Hidden.isHidden(hiddenDevices, address);
    }

    function setHidden(address, name, hidden) {
        set("hiddenDevices", Hidden.set(hiddenDevices, address, name, hidden));
    }

    function imageFor(device) {
        if (!imageFolder || !device)
            return "";
        // The device's own name, so a rename does not lose its pictures
        const name = (device.deviceName || device.name || "").replace(/[\/\\:*?"<>|]/g, "_");
        if (!name)
            return "";
        const folder = Paths.expandTilde(imageFolder).replace(/\/$/, "");
        return "file://" + folder + "/" + name + ".png";
    }

    // "<name> case.png", "<name> left.png", "<name> right.png" in the images
    // folder (EarbudArt falls back to the left picture mirrored)
    function partImageFor(device, part) {
        const base = imageFor(device);
        return base ? base.replace(/\.png$/, " " + part + ".png") : "";
    }

    property Connections _watch: Connections {
        target: PluginService
        function onPluginDataChanged(changedId) {
            if (changedId === root.pluginId)
                root._load();
        }
    }
}
