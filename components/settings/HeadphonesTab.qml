import QtQuick
import qs.Common
import qs.Modules.Plugins

// Headphones tab: noise control and the opt-in device pictures (D234).
Column {
    id: tab
    required property PluginSettings settings
    required property string batteryNote

    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    // --- Headphones --------------------------------------------------------------

    ToggleSetting {
        settingKey: "ancEnabled"
        label: "Noise control"
        description: "Supported headphones, 13 brands (needs python3)"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "ancEngine"
        label: "Engine"
        description: "\"Always connected\" shows headset button presses live · " + tab.batteryNote
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
        label: "Turn off conversation awareness on disconnect"
        description: "A disconnected headset would stay in conversation mode with no way to leave it. The noise-control mode is kept"
        defaultValue: true
    }

    // --- Pictures ----------------------------------------------------------------
    Section {
        text: "Device pictures"
    }

    ToggleSetting {
        settingKey: "realPictures"
        label: "Real device pictures (uses the internet)"
        description: "The only feature of Orbit that goes online. For each paired or connected device, its model name (for example \"WH-1000XM6\", never the Bluetooth address) is searched on commons.wikimedia.org, then on api.sketchfab.com; the picture is downloaded from upload.wikimedia.org or media.sketchfab.com and kept in ~/.cache/orbitBluetooth. Free licenses only, the author is credited in the detail card. Names that look personal are never sent"
        defaultValue: false
    }

    Row {
        ActionButton {
            text: "Delete downloaded pictures"
            onClicked: tab.settings.saveValue("picturesClear", Date.now())
        }
    }
}
