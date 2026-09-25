pragma Singleton
import QtQuick
QtObject {
    signal pluginDataChanged(string pluginId)
    property var globalVars: ({})
    function setGlobalVar(id, k, v) {}
    function savePluginData(id, k, v) {}
}
