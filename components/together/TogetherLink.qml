pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell.Io

// The one process of Listen together: a pw-loopback copying the sound of the
// output in use to the other one (Together.args). It exists only while a
// session wants it, and a new command (the output in use changed) replaces
// it. The command keeps bash watching its standard input: the pipe closes
// when the shell goes away, even after a crash, and takes the copy with it,
// so nothing outlives the shell (value 12). Nothing is written to any file.
Item {
    id: link

    // The argv of the copy, [] when there is nothing to run
    property var command: []
    // Said when the copy ended by itself (a crash, or both outputs gone), never
    // when this item stopped or replaced it
    signal lost

    // One delegate per command: a new command rebuilds it, which stops the
    // old process and starts the new one
    Instantiator {
        model: link.command.length ? [link.command] : []

        delegate: Process {
            id: proc
            required property var modelData
            command: modelData
            running: true
            // The pipe bash watches (see above)
            stdinEnabled: true
            onExited: code => {
                if (proc.modelData === link.command)
                    link.lost();
            }
        }
    }
}
