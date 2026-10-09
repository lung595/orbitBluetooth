import QtQuick
import Quickshell.Io
import "../common"
import "Signal.js" as Signal

// Reads a candidate's signal strength (Signal.js) with one busctl call, when
// asked: the new-device pop-up asks when a candidate appears and once more
// when its wait ends. Nothing runs otherwise, and reads go one at a time.
Item {
    id: root

    // [{path, done}] waiting behind the read in progress
    property var _queue: []
    property var _done: null

    // done(rssi): dBm, or undefined when there is no reading
    function read(device, done) {
        const command = Signal.command(device ? device.dbusPath : "");
        if (!command) {
            done(undefined);
            return;
        }
        _queue = _queue.concat([
            {
                "command": command,
                "done": done
            }
        ]);
        _next();
    }

    function _next() {
        if (proc.running || !_queue.length)
            return;
        _done = _queue[0].done;
        const command = _queue[0].command;
        _queue = _queue.slice(1);
        proc.launch(command);
    }

    ToolProcess {
        id: proc
        stdout: StdioCollector {
            id: out
        }
        // -1 (busctl not installed) parses to "no reading" like any failure,
        // so the caller is always answered
        onFinished: code => {
            const cb = root._done;
            root._done = null;
            if (cb)
                cb(Signal.parse(code, out.text));
            root._next();
        }
    }
}
