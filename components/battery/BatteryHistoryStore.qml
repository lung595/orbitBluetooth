import QtQuick
import Quickshell.Io
import qs.Common
import "BatterySessions.js" as Sessions

// Orbit's own battery history file: sessions per device, keyed by a salted
// hash, never an address or a name (values 11 and 12, D423 point 2). Not
// loaded by any view yet. The file is
// <XDG cache>/<plugin id>/battery/history.json, mode 0600 in a 0700 folder.
// Living in the cache folder, the uninstall sweep (UninstallSweep.qml) erases
// it with the rest. It is read once, on first use, and written only when
// a session ends: no timer, no polling.
Item {
    id: root

    required property string pluginId

    // The parsed history; replaced, never edited in place
    property var history: Sessions.newHistory(Math.random)

    readonly property string folder: Paths.strip(Paths.xdgCache) + "/" + pluginId + "/battery"
    readonly property string file: folder + "/history.json"

    property bool _loaded: false
    // A write was asked while one was running; one trailing write covers all
    // of them because the whole history is serialized each time
    property bool _dirty: false
    property bool _erasing: false

    // Read lazily on first use, so a save can never replace an unread file
    function _ensure() {
        if (_loaded)
            return;
        _loaded = true;
        reader.path = file;
        reader.reload();
        history = Sessions.parse(reader.text(), Math.random);
    }

    // Stores a finished session of the device with this Bluetooth address
    function recordSession(address, session) {
        _ensure();
        history = Sessions.record(history, Sessions.deviceKey(history.salt, address), session, Date.now());
        save();
    }

    // The device was seen at `at` (a disconnect, so a session end: no periodic write)
    function markSeen(address, at) {
        _ensure();
        history = Sessions.touch(history, Sessions.deviceKey(history.salt, address), at, Date.now());
        save();
    }

    function lastSeen(address) {
        _ensure();
        return Sessions.lastSeen(history, Sessions.deviceKey(history.salt, address));
    }

    function sessionsOf(address) {
        _ensure();
        return Sessions.sessionsOf(history, Sessions.deviceKey(history.salt, address));
    }

    // One call erases the history: the file goes, the in-memory copy restarts clean.
    // A write in flight is stopped first so it cannot put the file back.
    function erase() {
        _loaded = true;
        history = Sessions.newHistory(Math.random);
        _dirty = false;
        if (writer.running) {
            _erasing = true;
            writer.running = false;
            return;
        }
        _remove();
    }

    function _remove() {
        _erasing = false;
        remover.command = Sessions.eraseCommand(file);
        remover.running = true;
    }

    function save() {
        if (writer.running) {
            _dirty = true;
            return;
        }
        writer.command = Sessions.writeCommand(folder, file);
        // The previous run closed standard input; it must be open again to feed this one
        writer.stdinEnabled = true;
        writer.running = true;
    }

    FileView {
        id: reader
        blockLoading: true
        printErrors: false
    }

    Process {
        id: writer
        stdinEnabled: true
        onStarted: {
            write(Sessions.serialize(root.history));
            stdinEnabled = false;
        }
        onExited: {
            if (root._erasing)
                root._remove();
            else if (root._dirty) {
                root._dirty = false;
                root.save();
            }
        }
    }

    Process {
        id: remover
    }
}
