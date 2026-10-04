pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell.Io
import "Together.js" as Together

// The processes of Listen together: one pw-loopback per member that is
// copied to (Together.commands). It exists only while a session does, and
// only the copies that changed are stopped or started: a newcomer never
// cuts the others. Each command keeps bash watching its standard input: the
// pipe closes when the shell goes away, even after a crash, and takes the
// copy with it, so nothing outlives the shell (value 12). Nothing is written
// to any file.
Item {
    id: link

    // The copies wanted now, [{ key, command }] (Together.commands)
    property var copies: []
    // A copy ended by itself (a crash), never one this item stopped or replaced
    signal lost(string key)

    // key -> the command that runs for it. A row below is stopped or started
    // when this changes, and an exit of a row no longer listed here is ours
    property var _running: ({})

    // One row per running copy; ListModel rather than an array so that the
    // others keep running when one row is added or removed
    ListModel {
        id: rows
    }

    onCopiesChanged: _apply()
    // The first list is there before any change is signalled
    Component.onCompleted: _apply()

    // Stops and starts only what the new list changes
    function _apply() {
        const change = Together.diff(_running, copies);
        const next = Object.assign({}, _running);
        for (const key of change.stop) {
            delete next[key];
            for (let i = rows.count - 1; i >= 0; i--)
                if (rows.get(i).key === key)
                    rows.remove(i);
        }
        for (const copy of change.start) {
            next[copy.key] = copy.command;
            rows.append({
                "key": copy.key,
                "commandJson": JSON.stringify(copy.command)
            });
        }
        _running = next;
    }

    Instantiator {
        model: rows

        delegate: Process {
            id: proc
            required property string key
            required property string commandJson
            command: JSON.parse(commandJson)
            running: true
            // The pipe bash watches (see above)
            stdinEnabled: true
            onExited: {
                if (JSON.stringify(link._running[proc.key]) === proc.commandJson)
                    link.lost(proc.key);
            }
        }
    }
}
