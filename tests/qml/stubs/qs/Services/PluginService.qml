pragma Singleton
import QtQuick

QtObject {
    signal pluginDataChanged(string pluginId)
    property var globalVars: ({})
    // Plugin id -> manifest, as the plugin list; a test adds "smartTimer" to fake Sands
    property var availablePlugins: ({})
    property var pluginDaemonInstances: ({})
    function setGlobalVar(id, k, v) {
    }
    // What the plugin saved last, by key: the real service writes it to DMS's settings
    property var saved: ({})
    function savePluginData(id, k, v) {
        const next = Object.assign({}, saved);
        next[k] = v;
        saved = next;
    }
}
