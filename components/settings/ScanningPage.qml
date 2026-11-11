import QtQuick
import qs.Common
import qs.Modules.Plugins

// When Orbit looks for new devices.
CategoryPage {
    id: page
    category: "scanning"

    // --- Scanning ----------------------------------------------------------------

    ToggleSetting {
        settingKey: "autoScan"
        visible: page.shown("autoScan")
        label: page.label("autoScan")
        description: page.help("autoScan")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "offerNew"
        visible: page.shown("offerNew")
        label: page.label("offerNew")
        description: page.help("offerNew")
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "scanSeconds"
        visible: page.shown("scanSeconds")
        label: page.label("scanSeconds")
        description: page.help("scanSeconds")
        options: [
            {
                label: "20 seconds",
                value: "20"
            },
            {
                label: "45 seconds",
                value: "45"
            },
            {
                label: "90 seconds",
                value: "90"
            },
            {
                label: "While open",
                value: "0"
            }
        ]
        defaultValue: "45"
    }

    BatteryPill {
        forKey: "scanSeconds"
        visible: page.shown("scanSeconds")
    }
}
