import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../volume/Audiophile.js" as Audiophile

// The audio facts shown on a card and in the pop-up (D260).
CategoryPage {
    id: page
    category: "audio"

    StyledText {
        visible: !page.view.filtering
        width: parent.width
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        text: "Read from PipeWire only while the card or the pop-up shows. Pick what shows on the line or unfolds"
    }

    Repeater {
        model: Audiophile.INFOS
        Column {
            required property var modelData
            width: parent.width
            spacing: Theme.spacingXS
            ToggleSetting {
                settingKey: "factCard_" + modelData.key
                visible: page.shown(settingKey)
                label: modelData.label + ": on the line"
                defaultValue: modelData.card
            }
            ToggleSetting {
                settingKey: "factMore_" + modelData.key
                visible: page.shown(settingKey)
                label: modelData.label + ": more info"
                defaultValue: modelData.more
            }
        }
    }
}
