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
    readonly property bool autoScan: _get("autoScan", true)
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

    function imageFor(device) {
        if (!imageFolder || !device)
            return "";
        const name = (device.name || device.deviceName || "").replace(/[\/\\:*?"<>|]/g, "_");
        if (!name)
            return "";
        const folder = Paths.expandTilde(imageFolder).replace(/\/$/, "");
        return "file://" + folder + "/" + name + ".png";
    }

    property Connections _watch: Connections {
        target: PluginService
        function onPluginDataChanged(changedId) {
            if (changedId === root.pluginId)
                root._data = SettingsData.getPluginSettingsForPlugin(root.pluginId) || ({});
        }
    }
}
