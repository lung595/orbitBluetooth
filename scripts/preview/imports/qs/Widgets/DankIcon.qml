import QtQuick

Text {
    property string name: ""
    property real size: 20
    // DMS ships the icon font under DCommon/ since 2.1 (DankCommon/ before):
    // try the new folder first and fall back to the old one
    FontLoader {
        id: fl
        property bool old: false
        readonly property string font: "/assets/fonts/material-design-icons/variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"
        source: "file:///usr/share/quickshell/dms/" + (old ? "DankCommon" : "DCommon") + font
        onStatusChanged: if (status === FontLoader.Error && !old)
            old = true
    }
    text: name
    font.family: fl.name
    font.pixelSize: size
    width: size
    height: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
