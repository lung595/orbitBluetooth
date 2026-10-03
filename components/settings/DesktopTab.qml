import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets

// Desktop tab: the desktop widget's displays, backdrop and ambient motion.
Column {
    id: tab
    required property string pluginId
    required property string batteryNote

    // The desktop widget's own instance (Settings → Desktop Widgets): its
    // display choice is edited here with DMS's native picker
    readonly property var desktopInstance: (SettingsData.desktopWidgetInstances || []).find(w => w.widgetType === tab.pluginId) ?? null

    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    // --- Desktop -----------------------------------------------------------------

    SettingsDisplayPicker {
        visible: !!tab.desktopInstance
        displayPreferences: tab.desktopInstance?.config?.displayPreferences ?? ["all"]
        onPreferencesChanged: prefs => SettingsData.updateDesktopWidgetInstanceConfig(tab.desktopInstance.id, {
                "displayPreferences": prefs
            })
    }

    StyledText {
        width: parent.width
        visible: !tab.desktopInstance
        text: "Add Orbit Bluetooth in Settings → Desktop Widgets to choose its displays"
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    SliderSetting {
        settingKey: "desktopBackdrop"
        label: "Backdrop"
        description: "Veil behind the orbit"
        defaultValue: 72
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "desktopAmbient"
        label: "Ambient motion"
        description: "Keep moving when the pointer is away · " + tab.batteryNote
        defaultValue: false
    }
}
