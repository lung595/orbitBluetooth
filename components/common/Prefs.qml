import QtQuick
import qs.Common
import qs.Services
import "../volume/Audiophile.js" as Audiophile
import "../volume/Polar.js" as Polar
import "../volume/Steps.js" as Steps

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
    readonly property var _maps: ["ignoredDevices", "glyphOverrides", "hiddenDevices", "pcLevels"]
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
    // The same offer as a pop-up under the bar, found by a short background
    // scan while no view is open (see NewDeviceWatch)
    readonly property bool offerPopup: _get("offerPopup", true)
    // Orbit's own short scan every offerEvery seconds. Off by default: the
    // pop-up already catches what any other scan finds (DMS's Bluetooth
    // panel, system settings, an Orbit view), at no cost (P103)
    readonly property bool offerScan: _get("offerScan", false)
    readonly property int offerEvery: parseInt(_get("offerEvery", "60"))
    // No background scan on battery below this level (%)
    readonly property int offerMinBattery: _get("offerMinBattery", 30)
    // Devices the pop-up must never offer again: address -> name
    property var ignoredDevices: ({})
    readonly property bool autoScan: _get("autoScan", true)
    // Hover × on connected devices; off by default (drag away or right-click instead)
    readonly property bool quickDisconnect: _get("quickDisconnect", false)
    readonly property int scanSeconds: parseInt(_get("scanSeconds", "45"))
    readonly property bool sounds: _get("sounds", false)
    // A soft tick in the device on each 5 % volume step: on, since you asked for the volume yourself
    readonly property bool volumeTick: _get("volumeTick", true)
    readonly property real soundVolume: _get("soundVolume", 60) / 100
    readonly property bool shootingStars: _get("shootingStars", true)
    readonly property string starDensity: _get("starDensity", "normal")
    readonly property bool desktopAmbient: _get("desktopAmbient", false)
    readonly property real desktopBackdrop: _get("desktopBackdrop", 72) / 100
    readonly property string hostGlyph: _get("hostGlyph", "auto")
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
    // Look up real pictures of device models online (the only use of the
    // network, off by default, see pictures/orbit_pictures.py)
    readonly property bool realPictures: _get("realPictures", false)
    // Changes when the user empties the pictures cache
    readonly property var picturesClear: _get("picturesClear", 0)
    // Devices swallowed by the black hole: address -> name (the name keeps
    // the list readable when the device is out of range)
    property var hiddenDevices: ({})
    // Look of the black hole: "blackhole" (realistic) or "tesseract"
    readonly property string holeStyle: _get("holeStyle", "blackhole")

    // Two volumes (D249, D255): this PC's level on a virtual sink in front
    // of a device that has its own volume. Off: one level, as before
    readonly property bool separatePc: _get("separatePc", true)
    // This PC's level per device, address -> 0..1 (D256)
    property var pcLevels: ({})
    // The volume pop-up (D258): "replace" (in the Dank Island, else in place
    // of DMS's volume OSD, which is switched off, D273),
    // "bar" (under the bar widget), "edge" (right screen edge) or "off"
    readonly property string popupMode: _get("popupMode", "replace")
    // "compact", "medium" or "large"
    readonly property string popupSize: _get("popupSize", "medium")
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

    // The volume keys were offered once (D265): never again
    readonly property bool keysOffered: _get("keysOffered", false)

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

    function setIgnored(address, name, ignored) {
        const next = Object.assign({}, ignoredDevices);
        if (ignored)
            next[address] = name || address;
        else
            delete next[address];
        set("ignoredDevices", next);
    }

    function isHidden(address) {
        return !!address && hiddenDevices[address] !== undefined;
    }

    function setHidden(address, name, hidden) {
        const next = Object.assign({}, hiddenDevices);
        if (hidden)
            next[address] = name || address;
        else
            delete next[address];
        set("hiddenDevices", next);
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
