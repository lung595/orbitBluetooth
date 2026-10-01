import QtQuick
import qs.Common
import qs.Services

// Reactive view over the plugin's saved settings, shared by every surface.
QtObject {
    id: root

    readonly property string pluginId: "orbitBluetooth"

    property var _data: SettingsData.getPluginSettingsForPlugin(pluginId) || ({})

    function _get(key, def) {
        const v = _data[key];
        return v === undefined || v === null ? def : v;
    }

    readonly property bool showUnnamed: _get("showUnnamed", false)
    readonly property bool showLabels: _get("showLabels", true)
    readonly property int maxDevices: parseInt(_get("maxDevices", "8"))
    // Offer to connect a new unpaired device found while scanning
    readonly property bool offerNew: _get("offerNew", true)
    // The same offer as a pop-up under the bar, found by a short background
    // scan while no view is open (see NewDeviceWatch)
    readonly property bool offerPopup: _get("offerPopup", true)
    readonly property int offerEvery: parseInt(_get("offerEvery", "60"))
    // No background scan on battery below this level (%)
    readonly property int offerMinBattery: _get("offerMinBattery", 30)
    // Devices the pop-up must never offer again: address -> name
    readonly property var ignoredDevices: _get("ignoredDevices", ({}))
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
    readonly property string imageFolder: _get("imageFolder", "")
    readonly property var glyphOverrides: _get("glyphOverrides", ({}))
    readonly property bool ancEnabled: _get("ancEnabled", true)
    readonly property string ancEngine: _get("ancEngine", "demand")
    // Turn conversation awareness off when a headset disconnects or reconnects
    readonly property bool ancChatOff: _get("ancChatOff", true)
    // Look up real pictures of device models online (the only use of the
    // network, off by default, see pictures/orbit_pictures.py)
    readonly property bool realPictures: _get("realPictures", false)
    // Changes when the user empties the pictures cache
    readonly property var picturesClear: _get("picturesClear", 0)
    // Devices swallowed by the black hole: address -> name (the name keeps
    // the list readable when the device is out of range)
    readonly property var hiddenDevices: _get("hiddenDevices", ({}))
    // Look of the black hole: "blackhole" (realistic) or "tesseract"
    readonly property string holeStyle: _get("holeStyle", "blackhole")

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
                root._data = SettingsData.getPluginSettingsForPlugin(root.pluginId) || ({});
        }
    }
}
