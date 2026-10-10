import QtQuick
import qs.Common
import qs.Modules.Plugins

// Put things back, and report a problem.
CategoryPage {
    id: page
    category: "reset"
    required property PluginSettings settings

    Row {
        visible: page.shown("glyphOverrides") || page.shown("hiddenDevices") || page.shown("ignoredDevices")
        spacing: Theme.spacingS

        ActionButton {
            visible: page.shown("glyphOverrides")
            text: "Reset device icons"
            onClicked: page.settings.saveValue("glyphOverrides", ({}))
        }
        // Recovery path when the black hole is out of sight (e.g. a tiny widget)
        ActionButton {
            visible: page.shown("hiddenDevices")
            text: "Show hidden devices"
            onClicked: page.settings.saveValue("hiddenDevices", ({}))
        }
        // Devices refused with "Ignore" in the pop-up
        ActionButton {
            visible: page.shown("ignoredDevices")
            text: "Offer ignored devices again"
            onClicked: page.settings.saveValue("ignoredDevices", ({}))
        }
    }

    ReportRow {
        visible: page.shown("report")
    }
}
