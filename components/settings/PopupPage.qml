import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

// The volume pop-up and its visualizer.
CategoryPage {
    id: page
    category: "popup"

    SelectionSetting {
        settingKey: "popupMode"
        visible: page.shown("popupMode")
        label: page.label("popupMode")
        description: page.help("popupMode")
        options: [
            {
                label: "In the Dank Island",
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
                label: "Off (DMS's own OSD)",
                value: "off"
            }
        ]
        defaultValue: "replace"
    }

    StyledText {
        visible: page.shown("popupMode")
        width: parent.width
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        // Kept in full on purpose: the disclosure of D273 (the OSD flag is forced in memory only)
        text: "DMS's volume OSD is switched off in memory while a pop-up is on; Orbit writes nothing of DMS's, and it comes back when Orbit stops or the pop-up is Off"
    }

    SelectionSetting {
        settingKey: "popupSize"
        visible: page.shown("popupSize")
        label: page.label("popupSize")
        description: page.help("popupSize")
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
        settingKey: "popupScreens"
        visible: page.shown("popupScreens")
        label: page.label("popupScreens")
        description: page.help("popupScreens")
        options: [
            {
                label: "Where I am",
                value: "focused"
            },
            {
                label: "Every screen",
                value: "all"
            }
        ]
        defaultValue: "focused"
    }

    SelectionSetting {
        settingKey: "scopeStyle"
        visible: page.shown("scopeStyle")
        label: page.label("scopeStyle")
        description: page.help("scopeStyle")
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
        visible: page.shown("scopeFps")
        label: page.label("scopeFps")
        description: page.help("scopeFps")
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
        defaultValue: "30"
    }

    BatteryPill {
        forKey: "scopeFps"
        visible: page.shown("scopeFps")
    }
}
