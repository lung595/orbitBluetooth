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

    ToggleSetting {
        settingKey: "offerPopup"
        visible: page.shown("offerPopup")
        label: page.label("offerPopup")
        description: page.help("offerPopup")
        defaultValue: true
    }

    ToggleSetting {
        id: offerScan
        settingKey: "offerScan"
        visible: page.shown("offerScan")
        label: page.label("offerScan")
        description: page.help("offerScan")
        defaultValue: false
    }

    BatteryPill {
        forKey: "offerScan"
        visible: page.shown("offerScan")
    }

    SelectionSetting {
        settingKey: "offerEvery"
        // Only matters once the background scan is on
        visible: page.shown("offerEvery") && offerScan.value
        label: page.label("offerEvery")
        description: page.help("offerEvery")
        options: [
            {
                label: "Every 30 seconds",
                value: "30"
            },
            {
                label: "Every minute",
                value: "60"
            },
            {
                label: "Every 2 minutes",
                value: "120"
            },
            {
                label: "Every 5 minutes",
                value: "300"
            }
        ]
        defaultValue: "60"
    }

    BatteryPill {
        forKey: "offerEvery"
        visible: page.shown("offerEvery") && offerScan.value
    }

    SliderSetting {
        settingKey: "offerMinBattery"
        // Only matters once the background scan is on
        visible: page.shown("offerMinBattery") && offerScan.value
        label: page.label("offerMinBattery")
        description: page.help("offerMinBattery")
        defaultValue: 30
        minimum: 0
        maximum: 100
        unit: "%"
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
