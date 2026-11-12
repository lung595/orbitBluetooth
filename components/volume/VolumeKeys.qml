import QtQuick
import Quickshell.Io
import qs.Services
import "Keys.js" as Keys

// The volume keys and Orbit's smart steps (D265, NAK-214): reads what the two
// keys do, binds them to Orbit on the user's word only (`enable`; the keys
// are DMS's by default, as its OSD is) and gives them back to DMS's own
// action, through DMS's own `dms keybinds` command (argument lists only).
// Runs a command only at start or when asked: nothing at rest.
Item {
    id: root

    // The plugin's settings (Prefs): whether the user asked for the keys
    required property var prefs

    // "unsupported" (not niri), "unknown" (not read yet or unreadable),
    // "dms" (DMS's default: can be offered), "orbit" or "custom" (the
    // user's own shortcut: left alone)
    property string keys: CompositorService.isNiri ? "unknown" : "unsupported"
    readonly property bool busy: _queue.length > 0 || show.running || run.running
    // Last failure, for a short message (value 10)
    property bool failed: false

    property int _step: Keys.FALLBACK_STEP
    property var _mine: []
    property var _back: ({})
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
        // A plain re-read (`volumeKeys status`, the read after a set) must
        // not drop a bind or a give-back still waiting for its read: the
        // keys would stay DMS's while keysOrbit says Orbit's (audit 2026-11)
        if (then)
            _then = then;
        if (!show.running)
            show.running = true;
    }

    // Points both keys at Orbit, only if they still do DMS's default
    function _bind() {
        refresh(() => {
            if (root.keys !== "dms")
                return;
            root._run([Keys.setArgs("up", root._step), Keys.setArgs("down", root._step)]);
        });
    }

    // At start: the keys the user asked for are bound again. Up to 1.15 Orbit
    // took them by itself; those still bound to Orbit without the user's word
    // go back to DMS, once (keysReturned), so later starts run nothing
    function claim() {
        if (prefs.keysOrbit) {
            _bind();
        } else if (!prefs.keysReturned) {
            prefs.set("keysReturned", true);
            _giveBack();
        }
    }

    // The user asks for them (a button, the command line)
    function enable() {
        prefs.set("keysOrbit", true);
        _bind();
    }

    // The user gives them back
    function disable() {
        prefs.set("keysOrbit", false);
        _giveBack();
    }

    // Every key still bound to Orbit goes back to DMS's action, with its own step
    function _giveBack() {
        refresh(() => {
            if (root._mine.length > 0)
                root._run(root._mine.map(d => Keys.backArgs(d, root._back[d])));
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
            root._back = r.back;
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
