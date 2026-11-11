pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Together.js" as Together

// The processes of Listen together: one loopback process (pipewire -c,
// Route.loopbackArgs) per member that is copied to, and the filter of a wired
// source (Together.commands). It exists only while a session does, and
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
                if (!proc._cut)
                    link._lose(proc);
            }

            // pipewire -c, unlike pw-loopback, keeps running when its loopback
            // is destroyed (an output unplugged, PipeWire restarted): a node of
            // this process that was there and has been missing for 2 s while
            // it runs is taken as an exit. A node never seen is left alone.
            // Only Quickshell's own node list is read, and only while a
            // session runs: nothing polls.
            readonly property string node: Together.nodeOf(JSON.parse(commandJson))
            readonly property bool present: running && node !== "" && Pipewire.nodes.values.some(n => !!n && n.name === node)
            property bool _seen: false
            // Stopped by the watch: its exit, if one comes, is not lost twice
            property bool _cut: false
            onPresentChanged: {
                if (present) {
                    _seen = true;
                    gone.stop();
                } else if (_seen && running) {
                    gone.restart();
                }
            }
            property Timer _gone: Timer {
                id: gone
                interval: 2000
                onTriggered: {
                    if (!proc.running || proc.present)
                        return;
                    proc._cut = true;
                    proc.running = false;
                    link._lose(proc);
                }
            }
        }
    }

    // A copy that ended by itself, unless it is no longer the one wanted for its key
    function _lose(proc) {
        if (JSON.stringify(_running[proc.key]) === proc.commandJson)
            lost(proc.key);
    }
}
