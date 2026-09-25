import QtQuick
Text {
    property string name: ""
    property real size: 20
    FontLoader { id: fl; source: "file:///usr/share/quickshell/dms/DankCommon/assets/fonts/material-design-icons/variablefont/MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf" }
    text: name
    font.family: fl.name
    font.pixelSize: size
    width: size; height: size
    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
}
