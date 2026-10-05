import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "components/settings"

// Plugin settings, grouped by what they change. Every option works out of
// the box; descriptions stay one short line, and options that cost battery
// say so ("⚡ Uses more battery").
PluginSettings {
    id: root
    pluginId: "orbitBluetooth"

    readonly property string batteryNote: "⚡ Uses more battery"

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
            "id": "sound",
            "icon": "graphic_eq",
            "text": "Sound"
        },
        {
            "id": "desktop",
            "icon": "desktop_windows",
            "text": "Desktop"
        },
        {
            "id": "look",
            "icon": "palette",
            "text": "Look"
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

    OrbitTab {
        settings: root
        visible: root.tab === "orbit"
    }

    ScanningTab {
        settings: root
        batteryNote: root.batteryNote
        visible: root.tab === "scanning"
    }

    SoundTab {
        visible: root.tab === "sound"
    }

    HeadphonesTab {
        settings: root
        batteryNote: root.batteryNote
        visible: root.tab === "headphones"
    }

    DesktopTab {
        pluginId: root.pluginId
        batteryNote: root.batteryNote
        visible: root.tab === "desktop"
    }

    LookTab {
        visible: root.tab === "look"
    }
}
