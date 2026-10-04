import QtQuick
import qs.Common
import qs.Modules.Plugins
import "../device/Glyphs.js" as Glyphs

// Orbit tab: what the orbit shows, plus the reset buttons.
Column {
    id: tab
    required property PluginSettings settings

    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    // --- Orbit -----------------------------------------------------------------

    SelectionSetting {
        settingKey: "maxDevices"
        label: "Devices in orbit"
        description: "Connected devices always show"
        options: ["4", "6", "8", "10", "12"]
        defaultValue: "8"
    }

    ToggleSetting {
        settingKey: "showLabels"
        label: "Always show names"
        description: "Otherwise on hover"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showUnnamed"
        label: "Show unnamed devices"
        description: "Devices with only an address"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "quickDisconnect"
        label: "Quick disconnect button"
        description: "An × on connected devices, on hover"
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "hostGlyph"
        label: "Center device"
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
        label: "The listening source takes the center"
        description: "While Listen together plays, the source sits in the middle and the other outputs orbit it"
        defaultValue: true
    }

    // --- Reset -------------------------------------------------------------------
    Section {
        text: "Reset"
    }

    Row {
        spacing: Theme.spacingS

        ActionButton {
            text: "Reset device icons"
            onClicked: tab.settings.saveValue("glyphOverrides", ({}))
        }
        // Recovery path when the black hole is out of sight (e.g. a tiny widget)
        ActionButton {
            text: "Show hidden devices"
            onClicked: tab.settings.saveValue("hiddenDevices", ({}))
        }
        // Devices refused with "Ignore" in the pop-up
        ActionButton {
            text: "Offer ignored devices again"
            onClicked: tab.settings.saveValue("ignoredDevices", ({}))
        }
    }
}
