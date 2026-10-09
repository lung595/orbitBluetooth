import QtQuick
import qs.Common
import qs.Modules.Plugins

// Look tab: the black hole, stars and custom images.
Column {
    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    // --- Look --------------------------------------------------------------------

    SelectionSetting {
        settingKey: "holeStyle"
        label: "Black hole"
        description: "Where hidden devices go"
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
        label: "Charging beam"
        description: "How power flows to charging devices."
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
        defaultValue: "filament"
    }

    ToggleSetting {
        settingKey: "shootingStars"
        label: "Shooting stars"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "starDensity"
        label: "Stars"
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
        label: "Custom images folder"
        description: "PNGs named after devices replace their icons"
        placeholder: "~/Pictures/bluetooth"
        defaultValue: ""
    }
}
