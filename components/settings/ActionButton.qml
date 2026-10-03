import QtQuick
import qs.Common
import qs.Widgets

// A small flat button for one-shot actions on the settings page
Rectangle {
    id: action
    property string text: ""
    signal clicked

    width: actionText.implicitWidth + Theme.spacingL * 2
    height: 34
    radius: Theme.cornerRadius
    color: actionArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

    StyledText {
        id: actionText
        anchors.centerIn: parent
        text: action.text
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
    }
    MouseArea {
        id: actionArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: action.clicked()
    }
}
