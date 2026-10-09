import QtQuick
import Quickshell.Io
import qs.Services
import "Keys.js" as Keys

// The volume keys and Orbit's smart steps (D265, NAK-214): reads what the two
// keys do, binds them to Orbit (`claim` at the daemon's start, `enable` on the
// user's word) and gives them back to DMS's own action, through DMS's own
// `dms keybinds` command (argument lists only). The user's "give back" is
// remembered so that Orbit never takes the keys again by itself. Runs a
// command only at start or when asked: nothing at rest.
Item {
    id: root

    // The plugin's settings (Prefs): where "given back" is remembered
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
        _then = then || null;
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

    // At the first start: the keys are Orbit's by default, unless the user
    // gave them back (remembered) or has a shortcut of their own
    function claim() {
        if (prefs.keysGivenBack)
            return;
        _bind();
    }

    // The user asks for them (a button, the command line): forget a give-back
    function enable() {
        prefs.set("keysGivenBack", false);
        _bind();
    }

    // Gives back to DMS, with its own step, every key still bound to Orbit,
    // and remembers it
    function disable() {
        prefs.set("keysGivenBack", true);
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
