import QtQuick
import qs.Common

SettingRow {
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 52
        height: 30
        radius: 15
        color: parent.parent.value ? Theme.primary : Theme.surfaceContainerHighest
        border.width: parent.parent.value ? 0 : 2
        border.color: Theme.outline
        Rectangle {
            width: 22
            height: 22
            radius: 11
            y: 4
            x: parent.parent.parent.value ? 26 : 4
            color: parent.parent.parent.value ? Theme.primaryText : Theme.outline
        }
    }
}
