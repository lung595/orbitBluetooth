import QtQuick
import QtQuick.Window
import "../../components/volume"

// Offscreen bench of the scope's sound feed (NAK-210): ScopeFeed and the
// ScopeModel it moves, shown and hidden by the scene as VolumeOverlay does on
// a volume key. Nothing is spawned and nothing is captured: the stand-in cava
// sends a made-up 16-band frame at 60 Hz once it runs, and the stand-in peak
// meter a made-up reading at 47 Hz (one 1024-sample buffer at 48 kHz) while
// it is enabled, so what this measures is the QML side of each source. Never
// grabs, never quits. Made-up sink name only.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports scopefeed.qml -- <mode> /dev/null
// Modes: rest (the scope hidden), shown (the scope on screen, no key),
//        burst (every 4 s: the scope shows, 8 key steps 150 ms apart hold
//        cava back as VolumeOverlay's `_settled` does, the scope folds 3 s
//        after the last step)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]

    width: 200
    height: 120
    visible: true
    color: "#101114"

    property bool shown: mode === "shown"
    property bool settled: true

    ScopeFeed {
        id: feed
        node: ({
                "name": "alsa_output.fictional-dac.analog-stereo"
            })
        active: win.shown
        steady: win.settled
    }
    ScopeModel {
        feed: feed
        style: "points"
        gain: 0.7
    }

    // The stand-ins inside ScopeFeed: cava has a command, the meter peaks
    function part(key) {
        const all = feed.resources;
        for (let i = 0; i < all.length; i++)
            if (all[i] && all[i][key] !== undefined)
                return all[i];
        return null;
    }
    readonly property var cava: part("command")
    readonly property var meter: part("peaks")
    readonly property string line: {
        const v = [];
        for (let i = 0; i < 32; i++)
            v.push(Math.round(900 - i * 25));
        return v.join(";") + ";";
    }

    Timer {
        interval: 16
        repeat: true
        running: !!win.cava && win.cava.running
        onTriggered: win.cava.stdout.read(win.line)
    }
    Timer {
        property bool flip: false
        interval: 21
        repeat: true
        running: !!win.meter && win.meter.enabled
        onTriggered: {
            flip = !flip;
            win.meter.peaks = flip ? [0.62, 0.55] : [0.58, 0.6];
        }
    }

    // A burst every 4 s: show; 8 steps 150 ms apart end at 1.05 s, settled
    // 400 ms later; fold at 3.8 s, just before the next burst
    Timer {
        property int t: 0
        interval: 50
        repeat: true
        running: win.mode === "burst"
        onTriggered: {
            t = (t + 1) % 80;
            if (t === 0) {
                win.shown = true;
                win.settled = false;
            } else if (t === 29) {
                win.settled = true;
            } else if (t === 76) {
                win.shown = false;
            }
        }
    }
}
