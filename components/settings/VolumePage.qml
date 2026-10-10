import QtQuick
import qs.Common
import qs.Modules.Plugins

// The two volumes, volume steps and keys.
CategoryPage {
    id: page
    category: "volume"

    // --- Two volumes -------------------------------------------------------------

    ToggleSetting {
        settingKey: "separatePc"
        visible: page.shown("separatePc")
        label: page.label("separatePc")
        description: page.help("separatePc")
        defaultValue: true
    }

    SelectionSetting {
        id: volumeSteps
        settingKey: "volumeSteps"
        visible: page.shown("volumeSteps")
        label: page.label("volumeSteps")
        description: page.help("volumeSteps")
        options: [
            {
                label: "Smart",
                value: "smart"
            },
            {
                label: "Fixed",
                value: "fixed"
            }
        ]
        defaultValue: "smart"
    }

    SelectionSetting {
        settingKey: "volumeSpeed"
        visible: page.shown("volumeSpeed") && volumeSteps.value !== "fixed"
        label: page.label("volumeSpeed")
        description: page.help("volumeSpeed")
        options: [
            {
                label: "Gentle",
                value: "gentle"
            },
            {
                label: "Balanced",
                value: "balanced"
            },
            {
                label: "Fast",
                value: "fast"
            }
        ]
        defaultValue: "balanced"
    }

    SliderSetting {
        settingKey: "volumeStep"
        visible: page.shown("volumeStep") && volumeSteps.value === "fixed"
        label: page.label("volumeStep")
        description: page.help("volumeStep")
        defaultValue: 5
        minimum: 1
        maximum: 10
        unit: "%"
    }

    VolumeKeysRow {
        visible: page.shown("volumeKeys")
    }

    SelectionSetting {
        settingKey: "groupKeys"
        visible: page.shown("groupKeys")
        label: page.label("groupKeys")
        description: page.help("groupKeys")
        options: [
            {
                label: "Follow the last change",
                value: "follow"
            },
            {
                label: "Always the group volume",
                value: "group"
            },
            {
                label: "Always the last single device",
                value: "device"
            }
        ]
        defaultValue: "follow"
    }
}
