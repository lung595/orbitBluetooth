import QtQuick

// Preview stand-in: a file holding `content` (nothing by default), so nothing
// is read offscreen. Like the real one it loads when its path is set and again
// on reload().
QtObject {
    property string path: ""
    property string content: ""
    property bool printErrors: true
    property bool blockLoading: false
    signal loaded
    function text() {
        return content;
    }
    function reload() {
        loaded();
    }
    onPathChanged: if (path !== "")
        loaded()
}
