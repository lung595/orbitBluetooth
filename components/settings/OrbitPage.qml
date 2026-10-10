import QtQuick
import qs.Common
import qs.Modules.Plugins
import "../device/Glyphs.js" as Glyphs

// What the orbit shows: the devices, the center, groups.
CategoryPage {
    id: page
    category: "orbit"
    required property PluginSettings settings

    // --- Orbit -----------------------------------------------------------------

    SelectionSetting {
        settingKey: "maxDevices"
        visible: page.shown("maxDevices")
        label: page.label("maxDevices")
        description: page.help("maxDevices")
        options: ["4", "6", "8", "10", "12"]
        defaultValue: "8"
    }

    ToggleSetting {
        settingKey: "showLabels"
        visible: page.shown("showLabels")
        label: page.label("showLabels")
        description: page.help("showLabels")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showUnnamed"
        visible: page.shown("showUnnamed")
        label: page.label("showUnnamed")
        description: page.help("showUnnamed")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "quickDisconnect"
        visible: page.shown("quickDisconnect")
        label: page.label("quickDisconnect")
        description: page.help("quickDisconnect")
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "hostGlyph"
        visible: page.shown("hostGlyph")
        label: page.label("hostGlyph")
        description: page.help("hostGlyph")
        options: [
            {
                label: "Automatic",
                value: "auto"
            }
        ].concat(Glyphs.order.map(k => ({
                    label: Glyphs.label(k),
                    value: k
                })))
        defaultValue: "auto"
    }

    ToggleSetting {
        settingKey: "togetherCentre"
        visible: page.shown("togetherCentre")
        label: page.label("togetherCentre")
        description: page.help("togetherCentre")
        defaultValue: true
    }

    FineDelayRow {
        visible: page.shown("togetherFineDelay")
        owner: page
        settings: page.settings
    }

    HabitsRow {
        owner: page
        settings: page.settings
    }
}
