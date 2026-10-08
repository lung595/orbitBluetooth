import QtQuick

// Preview stand-in: a file that never loads, so nothing is read offscreen
QtObject {
    property string path: ""
    property bool printErrors: true
    signal loaded
    function text() {
        return "";
    }
}
