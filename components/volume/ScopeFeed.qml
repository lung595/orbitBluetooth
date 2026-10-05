import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Polar.js" as Polar

// What the vectorscope's cloud is made of: the sound going to an output,
// left and right, in 16 frequency bands per side, read by cava from the
// output's monitor. cava runs only while `active` (the scope is on screen
// and something moves on it); its configuration goes in through a file
// descriptor, never a file on disk (value 5) nor a shell string (value 11).
// Without cava, PipeWire's own peak meter gives one band per side.
Item {
    id: feed

    // The PipeWire sink whose sound is shown, e.g. bluez_output.<address>.1
    property var node: null
    property bool active: false
    property int fps: 60
    readonly property int bars: 16

    // Latest frame { l: [..], r: [..] } (0..1, low notes first), and when
    property var frame: null
    property double stamp: 0
    signal arrived

    property bool _noCava: false
    // Set while Orbit itself stops cava to move it to another output
    property bool _moving: false
    readonly property string _conf: (node && node.name && !_noCava) ? (Polar.cavaConfig(node.name + ".monitor", fps, bars) || "") : ""

    function _take(f) {
        if (!f)
            return;
        frame = f;
        stamp = Date.now();
        arrived();
    }

    Process {
        id: cava
        // bash only for the here-string: the configuration is "$1"
        command: ["bash", "-c", 'exec cava -p /dev/fd/3 3<<<"$1" </dev/null', "cava", feed._conf]
        running: feed.active && feed._conf !== ""
        stdout: SplitParser {
            onRead: line => feed._take(Polar.parseFrame(line, feed.bars))
        }
        // 127: not installed. Anything else that fails early also falls back
        onExited: code => {
            const moved = feed._moving;
            feed._moving = false;
            if (code !== 0 && feed.active && !moved)
                feed._noCava = true;
        }
    }

    // Another output while running: start again on it. Its exit is ours,
    // not a sign that cava is missing (it used to stick to the fallback)
    on_ConfChanged: if (cava.running) {
        _moving = true;
        cava.running = false;
        cava.running = Qt.binding(() => feed.active && feed._conf !== "");
    }
    onActiveChanged: if (!active)
        frame = null

    PwNodePeakMonitor {
        node: feed.node && feed.node.name ? feed.node : null
        enabled: feed.active && feed._noCava && !!(feed.node && feed.node.name)
        onPeaksChanged: {
            const p = peaks || [];
            if (p.length)
                feed._take({
                    "l": [Math.min(1, p[0] || 0)],
                    "r": [Math.min(1, (p.length > 1 ? p[1] : p[0]) || 0)]
                });
        }
    }
}
