import QtQuick
import qs.Common
import qs.Widgets

// Section title with air above it: hierarchy from size and weight only
StyledText {
    width: parent ? parent.width : 0
    topPadding: Theme.spacingXL
    bottomPadding: Theme.spacingXS
    font.pixelSize: Theme.fontSizeLarge
    font.weight: Font.Bold
    color: Theme.surfaceText
}
