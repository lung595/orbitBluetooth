import QtQuick
import Quickshell.Io
import qs.Services
import "Keys.js" as Keys

// The volume keys and Orbit's smart steps (D265): reads what the two keys
// do, binds them to Orbit when the user clicks "Enable" and gives them back
// to DMS on "Undo", through DMS's own `dms keybinds` command (argument
// lists only). Runs a command only when asked: nothing at rest.
Item {
    id: root

    // "unsupported" (not niri), "unknown" (not read yet or unreadable),
    // "dms" (DMS's default: can be offered), "orbit" or "custom" (the
    // user's own shortcut: left alone)
    property string keys: CompositorService.isNiri ? "unknown" : "unsupported"
    readonly property bool busy: _queue.length > 0 || show.running || run.running
    // Last failure, for a short message (value 10)
    property bool failed: false

    property int _step: Keys.FALLBACK_STEP
    property var _mine: []
    property var _queue: []
    // Called once after the next read
    property var _then: null

    function refresh(then) {
        if (!CompositorService.isNiri) {
            keys = "unsupported";
            if (then)
                then();
            return;
        }
        _then = then || null;
        if (!show.running)
            show.running = true;
    }

    // Points both keys at Orbit, only if they still do DMS's default
    function enable() {
        refresh(() => {
            if (root.keys !== "dms")
                return;
            root._run([Keys.setArgs("up", root._step), Keys.setArgs("down", root._step)]);
        });
    }

    // Gives back to DMS every key still bound to Orbit
    function disable() {
        refresh(() => {
            if (root._mine.length > 0)
                root._run(root._mine.map(d => Keys.resetArgs(d)));
        });
    }

    function _run(list) {
        failed = false;
        _queue = list;
        _next();
    }
    function _next() {
        if (_queue.length === 0) {
            refresh();
            return;
        }
        run.command = _queue[0];
        _queue = _queue.slice(1);
        run.running = true;
    }

    Process {
        id: show
        command: Keys.SHOW_ARGS
        stdout: StdioCollector {
            id: listing
        }
        onExited: code => {
            const r = Keys.classify(code === 0 ? listing.text : "");
            root.keys = r.state;
            root._step = r.step;
            root._mine = r.mine;
            const cb = root._then;
            root._then = null;
            if (cb)
                cb();
        }
    }

    Process {
        id: run
        stdout: StdioCollector {
            id: answer
        }
        onExited: code => {
            if (code !== 0 || !Keys.succeeded(answer.text)) {
                // Stop there; the read that follows shows what was done
                root.failed = true;
                root._queue = [];
            }
            root._next();
        }
    }
}
