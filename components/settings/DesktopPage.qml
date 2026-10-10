import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets

// The desktop widget's displays, backdrop and ambient motion.
CategoryPage {
    id: page
    category: "desktop"
    required property string pluginId

    // The desktop widget's own instance (Settings → Desktop Widgets): its
    // display choice is edited here with DMS's native picker
    readonly property var desktopInstance: (SettingsData.desktopWidgetInstances || []).find(w => w.widgetType === page.pluginId) ?? null

    SettingsDisplayPicker {
        visible: !!page.desktopInstance && !page.view.filtering
        displayPreferences: page.desktopInstance?.config?.displayPreferences ?? ["all"]
        onPreferencesChanged: prefs => SettingsData.updateDesktopWidgetInstanceConfig(page.desktopInstance.id, {
                "displayPreferences": prefs
            })
    }

    StyledText {
        width: parent.width
        visible: !page.desktopInstance && !page.view.filtering
        text: "Add Orbit Bluetooth in Settings → Desktop Widgets to choose its displays"
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    SliderSetting {
        settingKey: "desktopBackdrop"
        visible: page.shown("desktopBackdrop")
        label: page.label("desktopBackdrop")
        description: page.help("desktopBackdrop")
        defaultValue: 72
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "desktopAmbient"
        visible: page.shown("desktopAmbient")
        label: page.label("desktopAmbient")
        description: page.help("desktopAmbient")
        defaultValue: false
    }

    BatteryPill {
        forKey: "desktopAmbient"
        visible: page.shown("desktopAmbient")
    }
}
