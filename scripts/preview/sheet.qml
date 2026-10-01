import QtQuick
import QtQuick.Window
import qs.Common
import "../../components"
import "../../components/Offer.js" as Offer

// Offscreen renders of the pairing sheet with a given DMS palette.
// Usage: qml -I imports sheet.qml -- <palette> <phase> <out.png> [picture]
// Light palettes get the light skin, dark ones the dark skin (as in DMS)
// Palettes: green (dark), light, pastel, neon, mono, deepblue
// Phases: offer, pairing, connecting, done, failed, stack (offer + one waiting)
//         record: the whole story, a frame every 40 ms in <out> (a folder)
Window {
    id: win
    readonly property var opts: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string paletteName: opts[0]
    readonly property string phase: opts[1]
    readonly property string out: opts[2]
    readonly property string picture: opts[3] || ""

    // Shaped like matugen output: [isLight, primary, tertiary, surfaceContainer, high, text, muted, wallpaper top, bottom]
    readonly property var palettes: ({
            "green": [false, "#C5E66A", "#9FD3C7", "#1E201A", "#282B24", "#E4E3DB", "#C6C8B8", "#2b3a2a", "#141a14"],
            "light": [true, "#4B6818", "#386A60", "#EEEFE3", "#E8E9DD", "#1A1C16", "#45483C", "#c9d6b8", "#e9ecdf"],
            "pastel": [true, "#F2B8C6", "#B8D8F2", "#FFF0F2", "#F8E4E8", "#22191B", "#524346", "#f7d7de", "#dfe9f6"],
            "neon": [false, "#00FFD1", "#FF2E97", "#120F1C", "#1C1828", "#EDE7F6", "#B9B0CC", "#2a1035", "#081a24"],
            "mono": [false, "#BDBDBD", "#9E9E9E", "#1C1C1C", "#262626", "#EEEEEE", "#B0B0B0", "#2c2c2c", "#101010"],
            "deepblue": [false, "#1A3A8F", "#5B2C83", "#141A2A", "#1C2336", "#E2E6F3", "#A9B1C7", "#1b2a52", "#0b1020"]
        })
    readonly property var p: palettes[paletteName]

    width: 440
    height: 640
    visible: true

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: win.p[7] }
            GradientStop { position: 1; color: win.p[8] }
        }
    }
    // The bar, so the sheet reads as coming out of it
    Rectangle {
        width: parent.width
        height: 34
        color: Qt.rgba(0, 0, 0, win.p[0] ? 0.12 : 0.35)
    }

    readonly property bool recording: phase === "record"

    PairingSheet {
        id: sheet
        anchors.horizontalCenter: parent.horizontalCenter
        y: 36
        phase: win.phase === "stack" || win.recording ? "offer" : win.phase
        stacked: win.phase === "stack" ? 1 : 0
        name: "WH-1000XM6"
        subtitle: "Sony · Headphones"
        kind: "headphonesSlim"
        battery: 80
        life: win.recording ? Math.max(0, 1 - (win.now - win.started) / 30000) : 0.64
        features: Offer.features({ "family": "sony", "hours": 30, "kind": "headphonesSlim" })
        ancModes: [
            { "id": "nc", "icon": "noise_control_on", "label": "ANC" },
            { "id": "adaptive", "icon": "auto_awesome", "label": "Adaptive" },
            { "id": "ambient", "icon": "hearing", "label": "Ambient" },
            { "id": "off", "icon": "noise_control_off", "label": "Off" }
        ]
        ancMode: "nc"
        pictureSource: win.picture ? "file://" + win.picture : ""
        credit: win.picture ? "by Ada · CC BY 4.0 · Wikimedia Commons" : ""
    }

    Component.onCompleted: {
        Theme.isLightMode = p[0];
        Theme.primary = p[1];
        Theme.tertiary = p[2];
        Theme.surfaceContainer = p[3];
        Theme.surfaceContainerHigh = p[4];
        Theme.surfaceText = p[5];
        Theme.surfaceVariantText = p[6];
        Theme.error = p[0] ? "#BA1A1A" : "#FFB4AB";
    }
    property double started: Date.now()
    property double now: Date.now()
    property int frame: 0

    // Still: wait for the entrance to settle. Record: the whole story.
    Timer {
        interval: win.recording ? 40 : 3000
        running: true
        repeat: win.recording
        onTriggered: {
            if (!win.recording) {
                win.contentItem.grabToImage(r => {
                    r.saveToFile(win.out);
                    Qt.quit();
                });
                return;
            }
            win.now = Date.now();
            const t = win.now - win.started;
            sheet.phase = t < 4200 ? "offer" : t < 5300 ? "pairing" : t < 6400 ? "connecting" : "done";
            const n = win.frame++;
            win.contentItem.grabToImage(r => r.saveToFile(win.out + "/f" + String(n).padStart(4, "0") + ".png"));
            if (t > 9000) {
                stop();
                quitLater.start();
            }
        }
    }
    Timer {
        id: quitLater
        interval: 500
        onTriggered: Qt.quit()
    }
}
