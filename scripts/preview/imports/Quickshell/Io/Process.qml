import QtQuick

// Preview stand-in: the screenshots never run a command. Every one is listed
// in ProcessLog while it exists, for the tests.
QtObject {
    id: process

    property var command: []
    property bool running: false
    property bool stdinEnabled: false
    property var environment: ({})
    property QtObject stdout: null
    property QtObject stderr: null
    signal exited(int code)

    Component.onCompleted: ProcessLog.born(process)
    Component.onDestruction: ProcessLog.died(process)
}
