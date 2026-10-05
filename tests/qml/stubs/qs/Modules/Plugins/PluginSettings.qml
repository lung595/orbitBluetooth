import QtQuick

// Stands in for DMS's PluginSettings offscreen: a store the test fills (what
// the page would read) and a record of every save (what it would write). Like
// the real one, the service is handed over after the page is built.
Item {
    property string pluginId: "orbitBluetooth"
    property var pluginService: null
    property var stored: ({})
    // Every save, in order: [[key, value], …]
    property var saves: []

    function loadValue(key, defaultValue) {
        return stored[key] === undefined ? defaultValue : stored[key];
    }
    function saveValue(key, value) {
        stored[key] = value;
        saves = saves.concat([[key, value]]);
    }
}
