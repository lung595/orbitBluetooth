import QtQuick

// Preview stand-in: the screenshots never run a command. The tests drive a
// session by hand: `written` records what was sent to its standard input,
// and they raise `exited` themselves.
QtObject {
    property var command: []
    property bool running: false
    property var environment: ({})
    property bool stdinEnabled: false
    property QtObject stdout: null
    property QtObject stderr: null
    property var written: []
    signal exited(int code)
    function write(data) {
        written = written.concat([data]);
    }
}
