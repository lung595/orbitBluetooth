import QtQuick
import QtQuick.Window
import qs.Common
import "../../components"

// Offscreen render of the volume vectorscope, at the Dank Island sheet size (460 x 176), in each visualizer
// style, from a made-up stereo frame (no real sound or device involved).
// Usage: qml -I imports scope.qml -- <out.png>
Window {
    id: win
    readonly property string out: Qt.application.arguments[Qt.application.arguments.length - 1]
    width: 2 * 460 + 3 * 16
    height: 2 * 176 + 3 * 16
    visible: true
    color: "#2b3a24"

    readonly property NightColors night: NightColors {}
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
            Rectangle {
                id: frameBox
                required property string modelData
                width: 460
                height: 176
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainer, 0.92)
                border.color: Theme.withAlpha(Theme.outline, 0.4)
                Rectangle {
                    id: screen
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    radius: Math.max(0, Theme.cornerRadius - Theme.spacingS)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Qt.tint(win.night.sky, Theme.withAlpha(win.night.tertiary, 0.05))
                        }
                        GradientStop {
                            position: 1
                            color: Qt.tint(win.night.skyDeep, Theme.withAlpha(win.night.primary, 0.06))
                        }
                    }
                }
                PolarScope {
                    id: scope
                    anchors.centerIn: screen
                    width: screen.width - Theme.spacingXS * 2
                    height: screen.height - Theme.spacingXS * 2
                    style: frameBox.modelData
                    grid: true
                    deviceLevel: 0.62
                    pcLevel: 0.85
                    deviceIcon: "speaker"
                    live: true
                    deviceColor: win.night.primary
                    pcColor: win.night.tertiary
                    trackColor: win.night.ink(0.14)
                    inkColor: win.night.ink(0.92)
                    mutedColor: win.night.ink(0.4)
                    hollowColor: win.night.sky
                    Component.onCompleted: simulate(win.frame, 0.7)
                }
            }
        }
    }
    Timer {
        interval: 600
        running: true
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
