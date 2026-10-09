import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/device"
import "../../components/scene"

// Offscreen render of the charging beam styles from the product's own
// components (BeamLink), on the night sky, with made-up discs. Each style is
// shown moving and as its Reduce-motion still frame.
// Usage (OpenGL, Filament is a shader):
//   QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl \
//   qml-qt6 -I imports beams.qml -- png <style|all> <out.png>
//   ... beams.qml -- gif <style|all> <outDir>     frames f0000.png... at 25 fps, 4 s
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 3]
    readonly property string pick: args[args.length - 2]
    readonly property string out: args[args.length - 1]
    readonly property var styles: pick === "all" ? ["pulse", "filament", "chain", "horizon"] : [pick]
    readonly property real linkLength: 190
    // The clock the scene's 30 Hz timer would give; stepped by hand for a recording
    property real clock: 0

    width: 440
    height: styles.length * 216 + 20
    visible: true
    color: Theme.surface

    NightColors {
        id: tones
    }

    // A disc with a charge arc, standing for a host or a device
    component Disc: Item {
        property bool arc: false
        width: 44
        height: 44
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.withAlpha(tones.primary, 0.18)
            border.width: 1
            border.color: Theme.withAlpha(tones.primary, 0.5)
        }
        Rectangle {
            visible: parent.arc
            anchors.fill: parent
            anchors.margins: -4
            radius: width / 2
            color: "transparent"
            border.width: 3
            border.color: tones.charging
        }
    }

    Column {
        x: 20
        y: 10
        spacing: 0
        Repeater {
            model: win.styles
            delegate: Column {
                id: block
                required property string modelData
                width: 360
                Repeater {
                    // Moving, at rest (Reduce motion), and moving with the delay
                    // of a second charging device
                    model: [
                        {
                            "running": true,
                            "offset": 0,
                            "note": ""
                        },
                        {
                            "running": false,
                            "offset": 0,
                            "note": " · Reduce motion"
                        },
                        {
                            "running": true,
                            "offset": 0.5,
                            "note": " · second device (+0.5 s)"
                        }
                    ]
                    delegate: Item {
                        id: row
                        required property var modelData
                        width: 360
                        height: 72
                        Disc {
                            x: 0
                            y: 14
                        }
                        BeamLink {
                            x: 48
                            y: 14
                            width: win.linkLength
                            height: 44
                            style: block.modelData
                            running: row.modelData.running
                            offset: row.modelData.offset
                            deviceRadius: 22
                            reach: 26
                            time: win.clock
                            startColor: tones.primary
                            endColor: tones.charging
                        }
                        Disc {
                            x: 48 + win.linkLength + 4
                            y: 14
                            arc: true
                        }
                        Text {
                            x: 0
                            y: 62
                            text: block.modelData + row.modelData.note
                            color: Theme.withAlpha(tones.primary, 0.7)
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }

    property int frame: 0
    function pad(n) {
        return ("0000" + n).slice(-4);
    }
    // Let the window draw once, then grab (png) or step the clock and grab (gif)
    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            if (win.mode === "png") {
                win.clock = 1.1;
                if (win.frame++ > 3)
                    win.contentItem.grabToImage(r => {
                        r.saveToFile(win.out);
                        Qt.quit();
                    });
                return;
            }
            const n = win.frame++;
            win.contentItem.grabToImage(r => r.saveToFile(win.out + "/f" + win.pad(n) + ".png"));
            win.clock = (n + 1) * 0.04;
            if (n >= 99)
                Qt.quit();
        }
    }
}
