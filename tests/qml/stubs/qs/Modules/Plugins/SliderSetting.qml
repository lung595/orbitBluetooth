import QtQuick
import qs.Common
import qs.Widgets

SettingRow {
    id: sl
    property real minimum: 0
    property real maximum: 100
    property string unit: ""
    controlWidth: 150
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 100
        height: 4
        radius: 2
        color: Theme.surfaceContainerHighest
        Rectangle {
            width: parent.width * (sl.value - sl.minimum) / (sl.maximum - sl.minimum)
            height: 4
            radius: 2
            color: Theme.primary
        }
    }
    StyledText {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: sl.value + sl.unit
        font.pixelSize: Theme.fontSizeSmall
        font.features: {
            "tnum": 1
        }
        color: Theme.surfaceText
    }
}
