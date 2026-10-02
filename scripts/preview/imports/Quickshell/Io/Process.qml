import QtQuick

// Preview stand-in: the screenshots never run a command
QtObject {
    property var command: []
    property bool running: false
    property var environment: ({})
    property QtObject stdout: null
    property QtObject stderr: null
    signal exited(int code)
}
