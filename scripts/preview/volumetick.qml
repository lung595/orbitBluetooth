import QtQuick
import QtQuick.Window
import Quickshell.Io
import "../../components/volume"

// Offscreen bench of VolumeTick alone (NAK-8): the level is moved by the
// scene and the tick paced as the component decides. The resident players are
// the preview's stand-in Process (nothing is spawned, no sound is played), so
// this measures the shell's side only; what they were sent is let go every
// second so a long run does not grow. Made-up sink names only. Never quits.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports volumetick.qml -- <mode> /dev/null
// Modes: rest (nothing moves), sweep1 / sweep4 (one 1 % step every 25 ms,
//        40 a second, up then down, into 1 or 4 outputs), burst1 / burst4
//        (a 5 % jump once a second, into 1 or 4 outputs)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]
    readonly property int outputs: mode.endsWith("4") ? 4 : 1
    readonly property var nodes: [1, 2, 3, 4].slice(0, outputs).map(i => ({
                "name": "alsa_output.fictional-dac-" + i + ".analog-stereo"
            }))

    width: 200
    height: 120
    visible: true
    color: "#101114"

    // The plugin's settings, made up: the tick on, every 1 % (the default)
    QtObject {
        id: prefs
        property bool volumeTick: true
        property int tickEvery: 1
    }
    VolumeTick {
        id: tick
        prefs: prefs
    }

    // The level in whole percents, so a sweep never drifts
    property int level: 0
    property int dir: 1
    function move(by) {
        let next = level + by * dir;
        if (next > 100 || next < 0) {
            dir = -dir;
            next = level + by * dir;
        }
        tick.play(nodes, level / 100, next / 100);
        level = next;
    }

    Timer {
        interval: 25
        repeat: true
        running: win.mode.startsWith("sweep")
        onTriggered: win.move(1)
    }
    Timer {
        interval: 1000
        repeat: true
        running: win.mode.startsWith("burst")
        onTriggered: win.move(5)
    }
    // The stand-ins keep every line sent to them: forget them as they come
    Timer {
        interval: 1000
        repeat: true
        running: win.mode !== "rest"
        onTriggered: ProcessLog.live.forEach(p => p.written = [])
    }
}
