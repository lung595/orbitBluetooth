import QtQuick
// Mirrors DMS's StyledText defaults (wrap, elide, vertical centering) so
// previews lay text out like the real shell does
Text {
    font.pixelSize: 14
    color: "white"
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
