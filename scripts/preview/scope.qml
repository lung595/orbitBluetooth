import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/volume"
import "mock"
import "../../components/volume/Keys.js" as Keys

// Offscreen render of the volume vectorscope in each visualizer style, at
// the Dank Island sheet size (460 x 176, flat top corners), from a made-up
// stereo frame (no real sound or device involved).
// Usage: qml -I imports scope.qml -- <out.png> [light]
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property bool light: args[args.length - 1] === "light"
    readonly property string out: args[args.length - (light ? 2 : 1)]
    width: 2 * 460 + 3 * 16
    height: 2 * 176 + 3 * 16
    visible: true
    color: light ? "#d9d4c7" : "#2b3a24"

    // A light theme's accents are dark, made for light surfaces
    Component.onCompleted: if (light) {
        Theme.isLightMode = true;
        Theme.primary = "#4C6619";
        Theme.tertiary = "#2F6A5E";
        Theme.surfaceContainer = "#F1EFE6";
    }

    // A wide mix leaning a little left, bass in the middle
    readonly property var frame: ({
            "l": [0.92, 0.85, 0.8, 0.72, 0.66, 0.62, 0.55, 0.5, 0.44, 0.4, 0.33, 0.28, 0.22, 0.18, 0.12, 0.08],
            "r": [0.9, 0.8, 0.7, 0.66, 0.58, 0.5, 0.47, 0.4, 0.36, 0.3, 0.26, 0.2, 0.16, 0.12, 0.08, 0.05]
        })
    Grid {
        x: 16
        y: 16
        columns: 2
        spacing: 16
        Repeater {
            model: ["points", "rays", "waves", "none"]
            // The island's glass: flat corners against the screen edge
            Rectangle {
                id: sheet
                required property string modelData
                width: 460
                height: 176
                topLeftRadius: 4
                topRightRadius: 4
                bottomLeftRadius: Theme.cornerRadius * 2
                bottomRightRadius: Theme.cornerRadius * 2
                color: Theme.withAlpha(Theme.surfaceContainer, 0.92)
                ScopeScreen {
                    id: shown
                    anchors.fill: parent
                    radii: [4, 4, Theme.cornerRadius * 2, Theme.cornerRadius * 2]
                    overlay: FakeOverlay {
                        style: sheet.modelData
                        // The one-time volume keys note (D265) on two sheets
                        note: Keys.note(({
                                "waves": "offer",
                                "none": "done"
                            })[sheet.modelData] || "")
                    }
                    live: true
                }
                Timer {
                    interval: 100
                    running: true
                    onTriggered: shown.simulate(win.frame, 0.7)
                }
            }
        }
    }
    Timer {
        interval: 700
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
