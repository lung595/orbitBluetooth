import QtQuick

// Mock of Quickshell's peak meter: silent offscreen
QtObject {
    property var node: null
    property bool enabled: false
    property var peaks: []
}
