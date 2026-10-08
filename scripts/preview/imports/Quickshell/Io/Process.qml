import QtQuick

// Preview stand-in: the screenshots never run a command. Every one is listed
// in ProcessLog while it exists, and the tests drive a session by hand:
// `written` records what was sent to its standard input and they raise
// `started` and `exited` themselves. Like Quickshell, a program that is not
// installed sends neither: a test sets `running` back to false alone.
QtObject {
    id: process

    property var command: []
    property bool running: false
    property bool stdinEnabled: false
    property var environment: ({})
    property QtObject stdout: null
    property QtObject stderr: null
    property var written: []
    signal started
    signal exited(int code)

    function write(data) {
        written = written.concat([data]);
    }

    Component.onCompleted: ProcessLog.born(process)
    Component.onDestruction: ProcessLog.died(process)
}
