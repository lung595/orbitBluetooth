import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../common"

// A switch setting with a link to its section of the guide: ToggleSetting's
// look (a title, a line of description, the switch) with the GitHub mark in
// front of the switch. The row is as tall as its text, whatever the width.
// Like the other rows with a link, it reads the saved value once the service
// is handed over (and again when it changes elsewhere, such as a command
// line), and saves only when the switch is flipped, never while it loads.
// `value` follows it, for the settings that only matter while this one is on.
Row {
    id: row

    required property PluginSettings settings
    required property string settingKey
    required property string label
    property string description: ""
    // The guide's section (docs/GUIDE.md) the mark opens, by its anchor
    required property string anchor
    property bool defaultValue: false
    property bool value: defaultValue

    function load() {
        if (settings.pluginService)
            value = !!settings.loadValue(settingKey, defaultValue);
    }

    width: parent ? parent.width : 0
    spacing: Theme.spacingM

    // The service is handed over after the page is built: read on the next turn
    Component.onCompleted: Qt.callLater(load)
    Connections {
        target: row.settings.pluginService
        enabled: row.settings.pluginService !== null

        function onPluginDataChanged(pluginId) {
            if (pluginId === row.settings.pluginId)
                row.load();
        }
    }

    Column {
        width: parent.width - link.width - toggle.width - Theme.spacingM * 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        StyledText {
            text: row.label
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
        StyledText {
            width: parent.width
            visible: row.description !== ""
            wrapMode: Text.WordWrap
            text: row.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    GuideLink {
        id: link
        anchor: row.anchor
        anchors.verticalCenter: parent.verticalCenter
        size: 14
        color: Theme.surfaceVariantText
        hoverColor: Theme.surfaceText
    }

    DankToggle {
        id: toggle
        anchors.verticalCenter: parent.verticalCenter
        checked: row.value
        onToggled: isChecked => {
            row.value = isChecked;
            row.settings.saveValue(row.settingKey, isChecked);
        }
    }
}
