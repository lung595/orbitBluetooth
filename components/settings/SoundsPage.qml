import QtQuick
import qs.Common
import qs.Modules.Plugins

// Orbit's sounds.
CategoryPage {
    id: page
    category: "sounds"

    ToggleSetting {
        settingKey: "sounds"
        visible: page.shown("sounds")
        label: page.label("sounds")
        description: page.help("sounds")
        defaultValue: false
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
