pragma Singleton
import QtQuick

QtObject {
    property bool reduceMotion: false
    // DMS's layout: nothing placed, as on a fresh install
    property var barConfigs: []
    property var controlCenterWidgets: []
    property var desktopWidgetInstances: []
    property var pluginSettings: ({
            showUnnamed: false,
            showLabels: true,
            shootingStars: false
        })
    function getPluginSettingsForPlugin(id) {
        return pluginSettings;
    }
}
