import QtQuick
import QtQuick.Window

// Offscreen bench of "Disconnect after a delay" (NAK-403): DisconnectDelays on
// six made-up connected devices, driven by the scene. Never quits: it runs
// until the bench stops it. On a revision without the feature the Loader
// fails and the scene is just an empty window (the base).
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports delays.qml -- <mode> /dev/null
// Modes: rest (no delay pending), one (1 pending, 60 min), five (5 pending),
//        burst (start then cancel 5 delays every 100 ms)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]
    width: 200
    height: 120
    visible: true

    Loader {
        id: ld
        source: "../../components/delay/DisconnectDelays.qml"
        onLoaded: {
            const n = win.mode === "one" ? 1 : win.mode === "five" ? 5 : 0;
            for (let i = 1; i <= n; i++)
                item.start("Speaker " + i, 60);
        }
    }

    property bool on: true
    Timer {
        running: win.mode === "burst" && ld.item !== null
        interval: 100
        repeat: true
        onTriggered: {
            for (let i = 1; i <= 5; i++) {
                if (win.on)
                    ld.item.start("Speaker " + i, 60);
                else
                    ld.item.stop("Speaker " + i);
            }
            win.on = !win.on;
        }
    }
}
