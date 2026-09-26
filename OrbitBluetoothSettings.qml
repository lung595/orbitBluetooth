import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "components/Glyphs.js" as Glyphs

PluginSettings {
    id: root
    pluginId: "orbitBluetooth"

    StyledText {
        width: parent.width
        text: "Devices"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "maxDevices"
        label: "Devices in orbit"
        description: "Connected devices are always shown; the rest are ranked by pairing and name"
        options: ["4", "6", "8", "10", "12"]
        defaultValue: "8"
    }

    ToggleSetting {
        settingKey: "showUnnamed"
        label: "Show unnamed devices"
        description: "Devices that only expose a MAC address"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showLabels"
        label: "Always show names"
        description: "Otherwise names appear on hover"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "quickDisconnect"
        label: "Quick disconnect button"
        description: "An × on connected devices when hovered"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "autoScan"
        label: "Scan automatically"
        description: "Start discovery when a view opens; otherwise scan only from the center or the Scan chip"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "scanSeconds"
        label: "Scan duration"
        description: "Discovery stops after this delay or when the panel closes"
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

    SelectionSetting {
        settingKey: "hostGlyph"
        label: "Center device"
        description: "Icon of this machine"
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

    StringSetting {
        settingKey: "imageFolder"
        label: "Custom images folder (optional)"
        description: "PNG files named after the device (e.g. \"WH-1000XM6.png\") replace the built-in icon"
        placeholder: "~/Pictures/bluetooth"
        defaultValue: ""
    }

    StyledText {
        width: parent.width
        topPadding: Theme.spacingM
        text: "Noise control"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "ancEnabled"
        label: "Headphone noise control"
        description: "Noise cancelling, ambient sound and more for Sony, AirPods/Beats, Galaxy Buds, Bose, Nothing, Soundcore, Huawei/Honor, Oppo/OnePlus/realme, Redmi, EarFun, Moondrop, Haylou and 1MORE (needs python3)"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "ancEngine"
        label: "Engine"
        description: "On demand: the helper runs only while a headset card is open or a command is sent. Always connected: it stays connected to supported headsets, so button presses on the headset show up live (a small idle process)"
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

    StyledText {
        width: parent.width
        topPadding: Theme.spacingM
        text: "Look & feel"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "holeStyle"
        label: "Black hole style"
        description: "The black hole that keeps hidden devices"
        options: [
            {
                label: "Black hole",
                value: "blackhole"
            },
            {
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
        label: "Star density"
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

    SliderSetting {
        settingKey: "desktopBackdrop"
        label: "Desktop backdrop"
        description: "Depth of the smoky veil behind the desktop orbit; it always fades out at the edges"
        defaultValue: 72
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "desktopAmbient"
        label: "Ambient motion on desktop"
        description: "Keep orbits moving when the pointer is away (uses a little more power)"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "sounds"
        label: "Sounds"
        description: "Short cues on snap, connect and disconnect"
        defaultValue: false
    }

    SliderSetting {
        settingKey: "soundVolume"
        label: "Sound volume"
        defaultValue: 60
        minimum: 0
        maximum: 100
        unit: "%"
    }

    Rectangle {
        width: resetText.implicitWidth + Theme.spacingL * 2
        height: 34
        radius: Theme.cornerRadius
        color: resetArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

        StyledText {
            id: resetText
            anchors.centerIn: parent
            text: "Reset custom device icons"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }
        MouseArea {
            id: resetArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.saveValue("glyphOverrides", ({}))
        }
    }

    // Recovery path when the black hole is out of sight (e.g. a tiny widget)
    Rectangle {
        width: unhideText.implicitWidth + Theme.spacingL * 2
        height: 34
        radius: Theme.cornerRadius
        color: unhideArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

        StyledText {
            id: unhideText
            anchors.centerIn: parent
            text: "Show all hidden devices"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }
        MouseArea {
            id: unhideArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.saveValue("hiddenDevices", ({}))
        }
    }
}
