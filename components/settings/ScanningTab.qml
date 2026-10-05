import QtQuick
import qs.Common
import qs.Modules.Plugins

// Scanning tab: when Orbit looks for devices, and its sounds.
Column {
    id: tab
    required property PluginSettings settings
    required property string batteryNote

    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    // --- Scanning ----------------------------------------------------------------

    ToggleSetting {
        settingKey: "autoScan"
        label: "Scan automatically"
        description: "When a view opens; otherwise click the center"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "offerNew"
        label: "Offer new devices"
        description: "A card with Connect inside the Orbit view when an unpaired device shows up while scanning (the pop-up below has its own switch)"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "offerPopup"
        label: "Pop-up for new headphones"
        description: "Headphones in pairing mode found by any scan (Orbit, DMS's Bluetooth panel, system settings) are offered under the bar, even with Orbit closed. Free: it only listens"
        defaultValue: true
    }

    ToggleSetting {
        id: offerScan
        settingKey: "offerScan"
        label: "Background scan"
        description: "Also look for new headphones by itself, 8 s at a time, so the pop-up finds them without any panel open · " + tab.batteryNote
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "offerEvery"
        // Only matters once the background scan is on
        visible: offerScan.value
        label: "Background scan interval"
        description: "How often the background scan looks for new headphones (8 s each time). Skipped while Bluetooth audio is connected, since scanning makes it stutter"
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

    // --- Sounds ------------------------------------------------------------------
    Section {
        text: "Sounds"
    }

    ToggleSetting {
        settingKey: "sounds"
        label: "Sounds"
        description: "On snap, connect and disconnect"
        defaultValue: false
    }

    ToggleSetting {
        id: volumeTick
        settingKey: "volumeTick"
        label: "Volume tick"
        description: "A soft tick on each 5 % step, so you hear the level where it plays: in the output whose level you change, and in every output when it is the group's"
        defaultValue: true
    }

    LinkedToggle {
        settings: tab.settings
        // Only matters while the tick plays: without it DMS's sound is all there is
        visible: volumeTick.value
        settingKey: "tickAlone"
        label: "Orbit's tick only"
        description: "While you change a level in Orbit, DMS's own volume sound waits, so only the tick plays. DMS's own sliders and keys keep their sound"
        anchor: "orbits-tick-only"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "soundVolume"
        label: "Volume"
        defaultValue: 60
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "offerMinBattery"
        // Only matters once the background scan is on
        visible: offerScan.value
        label: "No background scan below"
        description: "Battery level of this computer, when it is not plugged in"
        defaultValue: 30
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SelectionSetting {
        settingKey: "scanSeconds"
        label: "Scan duration"
        description: "\"While open\": " + tab.batteryNote
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
}
