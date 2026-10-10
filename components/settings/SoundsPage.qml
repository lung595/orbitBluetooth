import QtQuick
import qs.Common
import qs.Modules.Plugins

// Orbit's sounds and the volume tick.
CategoryPage {
    id: page
    category: "sounds"
    required property PluginSettings settings

    ToggleSetting {
        settingKey: "sounds"
        visible: page.shown("sounds")
        label: page.label("sounds")
        description: page.help("sounds")
        defaultValue: false
    }

    ToggleSetting {
        id: volumeTick
        settingKey: "volumeTick"
        visible: page.shown("volumeTick")
        label: page.label("volumeTick")
        description: page.help("volumeTick")
        defaultValue: true
    }

    SelectionSetting {
        // Only matters while the tick plays
        visible: page.shown("tickEvery") && volumeTick.value
        settingKey: "tickEvery"
        label: page.label("tickEvery")
        description: page.help("tickEvery")
        options: [
            {
                label: "1 %",
                value: "1"
            },
            {
                label: "5 %",
                value: "5"
            }
        ]
        defaultValue: "1"
    }

    LinkedToggle {
        settings: page.settings
        // Only matters while the tick plays: without it DMS's sound is all there is
        visible: page.shown("tickAlone") && volumeTick.value
        settingKey: "tickAlone"
        label: page.label("tickAlone")
        description: page.help("tickAlone")
        anchor: "orbits-tick-only"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "soundVolume"
        visible: page.shown("soundVolume")
        label: page.label("soundVolume")
        description: page.help("soundVolume")
        defaultValue: 60
        minimum: 0
        maximum: 100
        unit: "%"
    }
}
