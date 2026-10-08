pragma Singleton
import QtQuick

QtObject {
    signal pluginDataChanged(string pluginId)
    property var globalVars: ({})
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
