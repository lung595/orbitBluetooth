import QtQuick
import qs.Common
import qs.Widgets

SettingRow {
    id: str
    property string placeholder: ""
    controlWidth: 150
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 150
        height: 32
        radius: 8
        color: Theme.surfaceContainerHighest
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            x: 8
            text: str.value || str.placeholder
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
}
