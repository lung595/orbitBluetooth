import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "BatterySessions.js" as Sessions

// Orbit's own battery history file: sessions per device, keyed by a salted
// hash, never an address or a name (values 11 and 12, D423 point 2). Not
// loaded by any view yet. The file is
// <XDG cache>/<plugin id>/battery/history.json, mode 0600 in a 0700 folder.
// Living in the cache folder, the uninstall sweep (UninstallSweep.qml) erases
// it with the rest. It is read once when asked and written only by
// save(), which the caller calls when a session ends: no timer, no polling.
Item {
    id: root

    required property string pluginId

    // The parsed history; replaced, never edited in place
    property var history: Sessions.newHistory(Math.random)

    readonly property string folder: Paths.strip(Paths.xdgCache) + "/" + pluginId + "/battery"
    readonly property string file: folder + "/history.json"

    function load() {
        reader.path = file;
        reader.reload();
        history = Sessions.parse(reader.text(), Math.random);
    }

    // Stores a finished session of the device with this Bluetooth address
    function recordSession(address, session) {
        const now = Date.now();
        history = Sessions.record(history, Sessions.deviceKey(history.salt, address), session, now);
        save();
    }

    function lastSeen(address) {
        return Sessions.lastSeen(history, Sessions.deviceKey(history.salt, address));
    }

    function sessionsOf(address) {
        return Sessions.sessionsOf(history, Sessions.deviceKey(history.salt, address));
    }

    // One call erases the history: the file goes, the in-memory copy restarts clean
    function erase() {
        history = Sessions.newHistory(Math.random);
        remover.running = false;
        remover.command = ["rm", "-f", "--", file];
        remover.running = true;
    }

    function save() {
        writer.running = false;
        // umask 077 makes the folder 0700 and the file 0600; the data comes in on
        // standard input and the paths as positional parameters, never in the string
        writer.command = ["sh", "-c", "umask 077; mkdir -p -- \"$1\" && cat > \"$2.tmp\" && mv -f -- \"$2.tmp\" \"$2\"", "sh", folder, file];
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
    }

    Process {
        id: remover
    }
}
