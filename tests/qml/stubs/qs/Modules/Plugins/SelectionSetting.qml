import QtQuick
import qs.Common
import qs.Widgets

SettingRow {
    id: sel
    property var options: []
    controlWidth: 110
    readonly property string shown: {
        const o = options.find(x => (x.value !== undefined ? x.value : x) === value);
        return o === undefined ? String(value) : (o.label !== undefined ? o.label : o);
    }
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 110
        height: 32
        radius: 16
        color: Theme.surfaceContainerHighest
        StyledText {
            anchors.centerIn: parent
            text: sel.shown
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }
}
