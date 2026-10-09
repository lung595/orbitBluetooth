import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Polar.js" as Polar

// What the vectorscope's cloud is made of: the sound going to an output,
// left and right, in 16 frequency bands per side, read by cava from the
// output's monitor. cava runs only while `active` (the scope is on screen
// and something moves on it); its configuration goes in through a file
// descriptor, never a file on disk (value 5) nor a shell string (value 11).
// PipeWire's own peak meter (one band per side) draws the cloud without
// cava, and until cava's first frame arrives (starting it takes a moment,
// and a burst of volume keys holds it back, D272): the scope moves at once
// and switches to the full spectrum without a gap.
Item {
    id: feed

    // The PipeWire sink whose sound is shown, e.g. bluez_output.<address>.1
    property var node: null
    property bool active: false
    // cava may start now. False during a burst of volume keys (D272): the
    // peak meter shows meanwhile. A cava already running is left alone
    property bool steady: true
    property int fps: 60
    readonly property int bars: 16

    // Latest frame { l: [..], r: [..] } (0..1, low notes first), and when
    property var frame: null
    property double stamp: 0
    signal arrived

    property bool _noCava: false
    // cava was allowed to start since the scope showed
    property bool _go: false
    // cava has delivered a frame since it (re)started
    property bool _spectrum: false
    onActiveChanged: {
        _syncGo();
        if (!active) {
            frame = null;
            _spectrum = false;
        }
    }
    onSteadyChanged: _syncGo()
    function _syncGo() {
        _go = active && (steady || _go);
    }
    // Set while Orbit itself stops cava to move it to another output
    property bool _moving: false
    readonly property string _conf: node && !_noCava ? (Polar.cavaConfig(node.name + ".monitor", fps, bars) || "") : ""

    function _take(f, fromCava) {
        if (!f)
            return;
        // The peak meter's late readings must not overwrite cava's frames
        if (!fromCava && _spectrum)
            return;
        if (fromCava)
            _spectrum = true;
        frame = f;
        stamp = Date.now();
        arrived();
    }

    Process {
        id: cava
        // bash only for the here-string: the configuration is "$1"
        command: ["bash", "-c", 'exec cava -p /dev/fd/3 3<<<"$1" </dev/null', "cava", feed._conf]
        running: feed._go && feed._conf !== ""
        stdout: SplitParser {
            onRead: line => feed._take(Polar.parseFrame(line, feed.bars), true)
        }
        // 127: not installed. Anything else that fails early also falls back
        onExited: code => {
            const moved = feed._moving;
            feed._moving = false;
            feed._spectrum = false;
            if (code !== 0 && feed.active && !moved)
                feed._noCava = true;
        }
    }

    // Another output while running: start again on it. Its exit is ours,
    // not a sign that cava is missing (it used to stick to the fallback)
    on_ConfChanged: if (cava.running) {
        _moving = true;
        cava.running = false;
        _spectrum = false;
        cava.running = Qt.binding(() => feed._go && feed._conf !== "");
    }

    PwNodePeakMonitor {
        node: feed.node
        enabled: feed.active && (feed._noCava || !feed._spectrum) && !!feed.node
        onPeaksChanged: {
            const p = peaks || [];
            if (p.length)
                feed._take({
                    "l": [Math.min(1, p[0])],
                    "r": [Math.min(1, p.length > 1 ? p[1] : p[0])]
                });
        }
    }
}
