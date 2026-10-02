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

    // The desktop widget's own instance (Settings → Desktop Widgets): its
    // display choice is edited here with DMS's native picker
    readonly property var desktopInstance: (SettingsData.desktopWidgetInstances || []).find(w => w.widgetType === root.pluginId) ?? null

    // Long settings are split into tabs (value 7): a row of chips, one
    // group shown at a time. Same look as Abyss's settings.
    property string tab: "orbit"
    readonly property var tabList: [
        {
            "id": "orbit",
            "icon": "bluetooth",
            "text": "Orbit"
        },
        {
            "id": "scanning",
            "icon": "bluetooth_searching",
            "text": "Scanning"
        },
        {
            "id": "headphones",
            "icon": "headphones",
            "text": "Headphones"
        },
        {
            "id": "desktop",
            "icon": "desktop_windows",
            "text": "Desktop"
        },
        {
            "id": "look",
            "icon": "palette",
            "text": "Look & sound"
        }
    ]

    Flow {
        width: parent ? parent.width : 0
        spacing: Theme.spacingS
        Repeater {
            model: root.tabList
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: root.tab === modelData.id
                height: 36
                width: chipRow.implicitWidth + 28
                radius: 18
                color: on ? Qt.tint(Theme.surfaceContainerHigh, Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)) : chipArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.width: on ? 1.5 : 0
                border.color: Theme.primary
                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 7
                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: chip.modelData.icon
                        size: 17
                        color: chip.on ? Theme.primary : Theme.surfaceText
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData.text
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: chip.on ? Font.DemiBold : Font.Normal
                        color: chip.on ? Theme.primary : Theme.surfaceText
                    }
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tab = chip.modelData.id
                }
            }
        }
    }

    Column {
        width: parent ? parent.width : 0
        spacing: Theme.spacingM
        visible: root.tab === "orbit"
        // --- Orbit -----------------------------------------------------------------

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
            // Devices refused with "Ignore" in the pop-up
            ActionButton {
                text: "Offer ignored devices again"
                onClicked: root.saveValue("ignoredDevices", ({}))
            }
        }
    }

    Column {
        width: parent ? parent.width : 0
        spacing: Theme.spacingM
        visible: root.tab === "scanning"
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
            description: "Also look for new headphones by itself, 8 s at a time, so the pop-up finds them without any panel open · " + root.batteryNote
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
    }

    Column {
        width: parent ? parent.width : 0
        spacing: Theme.spacingM
        visible: root.tab === "headphones"
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
    }

    Column {
        width: parent ? parent.width : 0
        spacing: Theme.spacingM
        visible: root.tab === "desktop"
        // --- Desktop -----------------------------------------------------------------

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
    }

    Column {
        width: parent ? parent.width : 0
        spacing: Theme.spacingM
        visible: root.tab === "look"
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

        ToggleSetting {
            settingKey: "volumeTick"
            label: "Volume tick"
            description: "A soft tick in the device on each 5 % step of its volume ring, so you hear the level where it plays"
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
    }
}
