pragma Singleton
import QtQuick
QtObject {
    property bool isLightMode: false
    property color primary: "#C5E66A"
    property color primaryText: "#1B2600"
    property color tertiary: "#9FD3C7"
    property color error: "#FFB4AB"
    property color errorText: "#690005"
    property color surface: "#12140E"
    property color surfaceContainer: "#1E201A"
    property color surfaceContainerHigh: "#282B24"
    property color surfaceContainerHighest: "#33362E"
    property color outline: "#909284"
    property color surfaceText: "#E4E3DB"
    property color surfaceVariantText: "#C6C8B8"
    property real fontSizeSmall: 12
    property real fontSizeMedium: 14
    property real fontSizeLarge: 16
    property real fontSizeXLarge: 20
    property real spacingXS: 4
    property real spacingS: 8
    property real spacingM: 12
    property real spacingL: 16
    property real cornerRadius: 12
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
}
