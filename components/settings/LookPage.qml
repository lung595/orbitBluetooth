import QtQuick
import qs.Common
import qs.Modules.Plugins
import "../device/BeamStyle.js" as BeamStyle

// The black hole, stars and custom images.
CategoryPage {
    id: page
    category: "look"

    SelectionSetting {
        settingKey: "holeStyle"
        visible: page.shown("holeStyle")
        label: page.label("holeStyle")
        description: page.help("holeStyle")
        options: [
            {
                label: "Black hole",
                value: "blackhole"
            },
            {
                // Named after the hypercube in Adventure Time
                label: "Three-dimensional shadow of a four-dimensional bubble",
                value: "tesseract"
            }
        ]
        defaultValue: "blackhole"
    }

    SelectionSetting {
        settingKey: "chargeBeamStyle"
        visible: page.shown("chargeBeamStyle")
        label: page.label("chargeBeamStyle")
        description: page.help("chargeBeamStyle")
        options: [
            {
                label: "Pulse",
                value: "pulse"
            },
            {
                label: "Filament",
                value: "filament"
            },
            {
                label: "Chain",
                value: "chain"
            },
            {
                label: "Horizon",
                value: "horizon"
            }
        ]
        defaultValue: BeamStyle.DEFAULT
    }

    ToggleSetting {
        settingKey: "shootingStars"
        visible: page.shown("shootingStars")
        label: page.label("shootingStars")
        description: page.help("shootingStars")
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "starDensity"
        visible: page.shown("starDensity")
        label: page.label("starDensity")
        description: page.help("starDensity")
        options: [
            {
                label: "Low",
                value: "low"
            },
            {
                label: "Normal",
                value: "normal"
            },
            {
                label: "High",
                value: "high"
            }
        ]
        defaultValue: "normal"
    }

    StringSetting {
        settingKey: "imageFolder"
        visible: page.shown("imageFolder")
        label: page.label("imageFolder")
        description: page.help("imageFolder")
        placeholder: "~/Pictures/bluetooth"
        defaultValue: ""
    }
}
