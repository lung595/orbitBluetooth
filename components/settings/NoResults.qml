import QtQuick
import qs.Common
import qs.Widgets

// What the content shows when a search matches nothing: one line to say so,
// one to say what to try. The rail stays usable.
Column {
    id: none

    required property string query

    spacing: Theme.spacingS
    topPadding: Theme.spacingXL

    DankIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: "search_off"
        size: 32
        color: Theme.surfaceVariantText
    }
    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        text: "Nothing matches “" + none.query.trim() + "”"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }
    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: "Try one word: tick, battery, pop-up, stars"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
}
