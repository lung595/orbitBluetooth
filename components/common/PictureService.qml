import QtQuick
import Quickshell.Io
import qs.Common

// Looks up a picture of each device model, only when the user turned on
// "Real device pictures" (off by default). It runs pictures/orbit_pictures.py,
// the only part of Orbit that uses the network (see its header for the exact
// hosts). One lookup at a time, each model once per session, and a model
// already in the local cache costs no network at all.
Item {
    id: root

    property bool active: false
    // Called with the model name -> {image, credit} map whenever it changes
    property var publish: function (map) {}
    // Changes when the user asks to empty the local cache
    property var clearToken: 0

    property var pictures: ({})
    property var _queue: []
    property var _asked: ({})
    property string _current: ""

    readonly property string _helper: Paths.strip(Qt.resolvedUrl("../../pictures/orbit_pictures.py"))

    function request(name) {
        if (!active || !name || _asked[name])
            return;
        const asked = Object.assign({}, _asked);
        asked[name] = true;
        _asked = asked;
        _queue = _queue.concat([name]);
        _next();
    }

    function _next() {
        if (finder.running || !_queue.length || !active)
            return;
        _current = _queue[0];
        _queue = _queue.slice(1);
        finder.command = ["python3", "-E", "-s", _helper, "find", _current];
        finder.running = true;
    }

    function _onLine(line) {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        // Turned off while a search ran: its answer is dropped
        if (!msg.image || !active)
            return;
        const next = Object.assign({}, pictures);
        next[msg.name] = {
            "image": "file://" + msg.image,
            "credit": msg.credit
        };
        pictures = next;
        publish(pictures);
    }

    Process {
        id: finder
        stdout: SplitParser {
            onRead: data => root._onLine(data)
        }
        onExited: root._next()
    }

    Process {
        id: eraser
    }

    onClearTokenChanged: {
        if (!clearToken)
            return;
        _queue = [];
        _asked = ({});
        pictures = ({});
        publish(pictures);
        eraser.command = ["python3", "-E", "-s", _helper, "clear"];
        eraser.running = true;
    }

    // Turned off: forget what is shown and erase the cache, which would
    // otherwise keep a list of every model ever looked up
    onEnabledChanged: {
        if (active)
            return;
        _queue = [];
        _asked = ({});
        pictures = ({});
        publish(pictures);
        finder.running = false;
        eraser.command = ["python3", "-E", "-s", _helper, "clear"];
        eraser.running = true;
    }

    Component.onDestruction: finder.running = false
}
