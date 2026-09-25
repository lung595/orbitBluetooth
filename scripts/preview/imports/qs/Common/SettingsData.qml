pragma Singleton
import QtQuick
QtObject {
    property bool reduceMotion: false
    property var pluginSettings: ({ showUnnamed: false, showLabels: true, shootingStars: false })
    function getPluginSettingsForPlugin(id) { return pluginSettings; }
}
