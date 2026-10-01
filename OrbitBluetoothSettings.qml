import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modules.Settings.Widgets
import "components/Glyphs.js" as Glyphs

// Plugin settings, grouped by what they change. Every option works out of
// the box; descriptions stay one short line, and options that cost battery
// say so ("⚡ Uses more battery").
PluginSettings {
    id: root
    pluginId: "orbitBluetooth"

    readonly property string batteryNote: "⚡ Uses more battery"

    // Section title with air above it: hierarchy from size and weight only
    component Section: StyledText {
        width: parent ? parent.width : 0
        topPadding: Theme.spacingXL
        bottomPadding: Theme.spacingXS
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    component ActionButton: Rectangle {
        id: action
        property string text: ""
        signal clicked

        width: actionText.implicitWidth + Theme.spacingL * 2
        height: 34
        radius: Theme.cornerRadius
        color: actionArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

        StyledText {
            id: actionText
            anchors.centerIn: parent
            text: action.text
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }
        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }

    // --- Orbit -----------------------------------------------------------------
    Section {
        topPadding: 0
        text: "Orbit"
    }

    SelectionSetting {
        settingKey: "maxDevices"
        label: "Devices in orbit"
        description: "Connected devices always show"
        options: ["4", "6", "8", "10", "12"]
        defaultValue: "8"
    }

    ToggleSetting {
        settingKey: "showLabels"
        label: "Always show names"
        description: "Otherwise on hover"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showUnnamed"
        label: "Show unnamed devices"
        description: "Devices with only an address"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "quickDisconnect"
        label: "Quick disconnect button"
        description: "An × on connected devices, on hover"
        defaultValue: false
    }

    SelectionSetting {
        settingKey: "hostGlyph"
        label: "Center device"
        options: [
            {
                label: "Automatic",
                value: "auto"
            }
        ].concat(Glyphs.order.map(k => ({
                    label: Glyphs.label(k),
                    value: k
                })))
        defaultValue: "auto"
    }

    // --- Scanning ----------------------------------------------------------------
    Section {
        text: "Scanning"
    }

    ToggleSetting {
        settingKey: "autoScan"
        label: "Scan automatically"
        description: "When a view opens; otherwise click the center"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "offerNew"
        label: "Offer new devices"
        description: "A card with Connect when an unpaired device shows up while scanning"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "scanSeconds"
        label: "Scan duration"
        description: "\"While open\": " + root.batteryNote
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

    // --- Headphones --------------------------------------------------------------
    Section {
        text: "Headphones"
    }

    ToggleSetting {
        settingKey: "ancEnabled"
        label: "Noise control"
        description: "Supported headphones, 13 brands (needs python3)"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "ancEngine"
        label: "Engine"
        description: "\"Always connected\" shows headset button presses live · " + root.batteryNote
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
            onClicked: root.saveValue("picturesClear", Date.now())
        }
    }

    // --- Desktop -----------------------------------------------------------------
    Section {
        text: "Desktop widget"
    }

    // The desktop widget's own instance (Settings → Desktop Widgets): its
    // display choice is edited here with DMS's native picker
    readonly property var desktopInstance: (SettingsData.desktopWidgetInstances || []).find(w => w.widgetType === root.pluginId) ?? null

    SettingsDisplayPicker {
        visible: !!root.desktopInstance
        displayPreferences: root.desktopInstance?.config?.displayPreferences ?? ["all"]
        onPreferencesChanged: prefs => SettingsData.updateDesktopWidgetInstanceConfig(root.desktopInstance.id, {
                "displayPreferences": prefs
            })
    }

    StyledText {
        width: parent.width
        visible: !root.desktopInstance
        text: "Add Orbit Bluetooth in Settings → Desktop Widgets to choose its displays"
        wrapMode: Text.WordWrap
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    SliderSetting {
        settingKey: "desktopBackdrop"
        label: "Backdrop"
        description: "Veil behind the orbit"
        defaultValue: 72
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "desktopAmbient"
        label: "Ambient motion"
        description: "Keep moving when the pointer is away · " + root.batteryNote
        defaultValue: false
    }

    // --- Look --------------------------------------------------------------------
    Section {
        text: "Look"
    }

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

    SliderSetting {
        settingKey: "soundVolume"
        label: "Volume"
        defaultValue: 60
        minimum: 0
        maximum: 100
        unit: "%"
    }

    // --- Reset -------------------------------------------------------------------
    Section {
        text: "Reset"
    }

    Row {
        spacing: Theme.spacingS

        ActionButton {
            text: "Reset device icons"
            onClicked: root.saveValue("glyphOverrides", ({}))
        }
        // Recovery path when the black hole is out of sight (e.g. a tiny widget)
        ActionButton {
            text: "Show hidden devices"
            onClicked: root.saveValue("hiddenDevices", ({}))
        }
    }
}
