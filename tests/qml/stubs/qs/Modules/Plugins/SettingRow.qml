import QtQuick
import qs.Common
import qs.Widgets

// What the DMS setting widgets share offscreen: a label and its help on the
// left, the control (a child) on the right.
Item {
    id: row
    property string settingKey: ""
    property string label: ""
    property string description: ""
    property var defaultValue
    property var value: defaultValue
    default property alias control: slot.data
    property real controlWidth: 52

    width: parent ? parent.width : 0
    height: visible ? Math.max(48, texts.implicitHeight + Theme.spacingM) : 0

    Column {
        id: texts
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - row.controlWidth - Theme.spacingM
        StyledText {
            width: parent.width
            text: row.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }
        StyledText {
            width: parent.width
            visible: text !== ""
            text: row.description
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: row.controlWidth
        height: 32
    }
}
