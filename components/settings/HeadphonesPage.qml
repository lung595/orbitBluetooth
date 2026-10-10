import QtQuick
import qs.Common
import qs.Modules.Plugins

// Noise control and the opt-in device pictures (D234).
CategoryPage {
    id: page
    category: "headphones"
    required property string batteryNote
    required property PluginSettings settings

    // --- Headphones --------------------------------------------------------------

    ToggleSetting {
        settingKey: "ancEnabled"
        visible: page.shown("ancEnabled")
        label: page.label("ancEnabled")
        description: page.help("ancEnabled")
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "ancEngine"
        visible: page.shown("ancEngine")
        label: page.label("ancEngine")
        description: page.help("ancEngine") + " · " + page.batteryNote
        options: [
            {
                label: "On demand",
                value: "demand"
            },
            {
                label: "Always connected",
                value: "live"
            }
        ]
        defaultValue: "demand"
    }

    ToggleSetting {
        settingKey: "ancChatOff"
        visible: page.shown("ancChatOff")
        label: page.label("ancChatOff")
        description: page.help("ancChatOff")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "wearPause"
        visible: page.shown("wearPause")
        label: page.label("wearPause")
        description: page.help("wearPause")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "realPictures"
        visible: page.shown("realPictures")
        label: page.label("realPictures")
        description: page.help("realPictures")
        defaultValue: false
    }

    Row {
        visible: page.shown("picturesClear")
        ActionButton {
            text: "Delete downloaded pictures"
            onClicked: page.settings.saveValue("picturesClear", Date.now())
        }
    }
}
