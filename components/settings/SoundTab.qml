import QtQuick
import qs.Common
import qs.Modules.Plugins

// Sound tab: the two volumes, volume steps and keys, and the volume pop-up.
Column {
    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    // --- Two volumes -------------------------------------------------------------

    ToggleSetting {
        settingKey: "separatePc"
        label: "Separate PC volume"
        description: "For devices with a volume of their own: the device's level and what this PC sends to it, set apart"
        defaultValue: true
    }

    // --- Volume steps (D264) --------------------------------------------------------
    Section {
        text: "Volume steps"
    }

    SelectionSetting {
        id: volumeSteps
        settingKey: "volumeSteps"
        label: "Steps"
        description: "For the volume keys bound to Orbit (dms ipc call orbitBluetooth volume up or down) and the wheel over the pop-up. Smart: slow notches move by 1 % for precision, a quick run builds up speed, and turning back to look for a spot holds it a little"
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
        visible: volumeSteps.value !== "fixed"
        label: "Speed-up"
        description: "How far a quick run can go per notch: Gentle up to 3 %, Balanced up to 4 %, Fast up to 6 %. Slow notches are always 1 %, and so is every step under 10 %"
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
        visible: volumeSteps.value === "fixed"
        label: "Step"
        defaultValue: 5
        minimum: 1
        maximum: 10
        unit: "%"
    }

    VolumeKeysRow {}

    // --- Volume pop-up -------------------------------------------------------------
    Section {
        text: "Volume pop-up"
    }

    SelectionSetting {
        settingKey: "popupMode"
        label: "Pop-up"
        description: "Shows both levels whenever one changes"
        options: [
            {
                label: "In place of DMS's volume OSD",
                value: "replace"
            },
            {
                label: "Under the bar widget",
                value: "bar"
            },
            {
                label: "Right screen edge",
                value: "edge"
            },
            {
                label: "Off (DMS's OSD)",
                value: "off"
            }
        ]
        defaultValue: "replace"
    }

    SelectionSetting {
        settingKey: "popupSize"
        label: "Size"
        options: [
            {
                label: "Compact",
                value: "compact"
            },
            {
                label: "Medium",
                value: "medium"
            },
            {
                label: "Large",
                value: "large"
            }
        ]
        defaultValue: "medium"
    }

    SelectionSetting {
        settingKey: "scopeStyle"
        label: "Visualizer"
        description: "How the sound is drawn inside the half circles: a cloud of points (where it sits left or right), a fan of rays or waves (its notes, bass at the top)"
        options: [
            {
                label: "Points",
                value: "points"
            },
            {
                label: "Rays",
                value: "rays"
            },
            {
                label: "Waves",
                value: "waves"
            },
            {
                label: "None",
                value: "none"
            }
        ]
        defaultValue: "points"
    }

    SelectionSetting {
        settingKey: "scopeFps"
        label: "Visualizer motion"
        description: "While the pop-up or a card shows, nothing otherwise. \"Light\" draws half as often"
        options: [
            {
                label: "Smooth",
                value: "60"
            },
            {
                label: "Light",
                value: "30"
            }
        ]
        defaultValue: "60"
    }
}
