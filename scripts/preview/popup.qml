import QtQuick
import QtQuick.Window
import qs.Common
import "../../components"

// Offscreen renders of the "new device" pop-up, at a given moment.
// Usage: qml -I imports popup.qml -- <phase> <milliseconds> <out.png> [picture]
// Phases: offer, pairing, connecting, done, failed
//         record: plays the whole story (arrival, Connect, connected) and
//         saves a frame every 40 ms as <out>/f0000.png ... (out is a folder)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    // Everything after "--"
    readonly property var opts: args.slice(args.indexOf("--") + 1)
    readonly property string phase: opts[0]
    readonly property int at: parseInt(opts[1])
    readonly property string out: opts[2]
    readonly property string picture: opts[3] || ""
    readonly property bool recording: phase === "record"
    width: 520
    height: 210
    visible: true
    color: "#2a3140"

    // Wallpaper stand-in (grabToImage does not include the window colour)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#33405a" }
            GradientStop { position: 1; color: "#5a4a63" }
        }
    }

    // A bar, so the drop from it reads
    Rectangle {
        width: parent.width
        height: 10
        color: "#141821"
    }

    NewDevicePopup {
        id: popup
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6
        name: "WH-1000XM6"
        kind: "headphonesSlim"
        headline: "New headphones nearby"
        phase: win.recording ? "offer" : win.phase
        life: win.recording ? 1 - Math.min(1, (win.now - win.started) / 20000) : 0.62
        battery: 80
        pictureSource: win.picture ? "file://" + win.picture : ""
        credit: win.picture ? "by Ada · CC BY 4.0 · Wikimedia Commons" : ""
    }

    property double started: Date.now()
    property double now: Date.now()
    property int frame: 0

    Component.onCompleted: {
        popup.shown = true;
        if (recording) {
            ticker.start();
            return;
        }
        grabTimer.interval = Math.max(30, win.at);
        grabTimer.start();
    }

    // The story: arrival, a moment of sonar, Connect, pairing, connected
    Timer {
        id: ticker
        interval: 40
        repeat: true
        onTriggered: {
            win.now = Date.now();
            const t = win.now - win.started;
            popup.phase = t < 2600 ? "offer" : t < 3500 ? "pairing" : t < 4500 ? "connecting" : "done";
            const n = win.frame++;
            win.contentItem.grabToImage(r => r.saveToFile(win.out + "/f" + String(n).padStart(4, "0") + ".png"));
            if (t > 6600) {
                stop();
                quitTimer.start();
            }
        }
    }
    Timer {
        id: quitTimer
        interval: 400
        onTriggered: Qt.quit()
    }
    Timer {
        id: grabTimer
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
