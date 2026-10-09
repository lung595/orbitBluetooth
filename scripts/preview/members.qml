import QtQuick
import QtQuick.Window
import qs.Common
import "../../components/volume"
import "mock"

// Offscreen render of the vectorscope with outputs listening together (D277):
// two, three and four, long names, one muted, all at full level, a device
// alone and no device, at the Dank Island sheet size (460 x 176), from made-up
// levels and a made-up stereo frame (no real sound, device or name involved).
// Usage: qml -I imports members.qml -- <out.png> [light] [points|rays|waves]
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property bool light: args.includes("light")
    readonly property string style: ["rays", "waves"].find(a => args.includes(a)) || "points"
    readonly property string out: args.find(a => a.endsWith(".png")) || "members.png"
    width: 2 * 460 + 3 * 16
    height: 4 * 176 + 5 * 16
    visible: true
    color: light ? "#d9d4c7" : "#2b3a24"

    // A light theme's accents are dark, made for light surfaces
    Component.onCompleted: if (light) {
        Theme.isLightMode = true;
        Theme.primary = "#4C6619";
        Theme.secondary = "#5A4E7C";
        Theme.tertiary = "#2F6A5E";
        Theme.surfaceContainer = "#F1EFE6";
    }

    readonly property var frame: ({
            "l": [0.92, 0.85, 0.8, 0.72, 0.66, 0.62, 0.55, 0.5, 0.44, 0.4, 0.33, 0.28, 0.22, 0.18, 0.12, 0.08],
            "r": [0.9, 0.8, 0.7, 0.66, 0.58, 0.5, 0.47, 0.4, 0.36, 0.3, 0.26, 0.2, 0.16, 0.12, 0.08, 0.05]
        })
    function member(i, level, muted, icon, label, target) {
        return {
            "part": "m" + i,
            "address": "02:00:00:00:00:0" + i,
            "level": level,
            "muted": muted,
            "icon": icon,
            "label": label,
            "target": target === true
        };
    }
    // Each case: the outputs listening together ([] none), the device's own
    // level (-1: none) when they do not, this PC's level, and a title
    readonly property var cases: [
        {
            "members": [member(0, 0.7, false, "headphones", "Studio headphones"), member(1, 0.4, false, "speaker", "Desk speaker")],
            "pc": 0.85
        },
        {
            "members": [member(0, 0.8, false, "headphones", "Studio headphones"), member(1, 0.5, false, "speaker", "Desk speaker", true), member(2, 0.3, false, "earbuds", "Earbuds")],
            "pc": 0.85
        },
        {
            "members": [member(0, 0.9, false, "headphones", "Studio headphones"), member(1, 0.6, false, "speaker", "Desk speaker"), member(2, 0.4, false, "earbuds", "Earbuds"), member(3, 0.2, false, "speaker", "Kitchen speaker")],
            "pc": 0.85
        },
        {
            "members": [member(0, 0.75, false, "headphones", "Studio headphones with a very long name"), member(1, 0.55, true, "speaker", "Desk speaker"), member(2, 0.9, false, "earbuds", "Earbuds"), member(3, 0.35, false, "speaker", "Another speaker with a long name")],
            "pc": 0.6
        },
        {
            "members": [member(0, 1, false, "headphones", "Studio headphones"), member(1, 1, false, "speaker", "Desk speaker"), member(2, 1, false, "earbuds", "Earbuds"), member(3, 1, false, "speaker", "Kitchen speaker")],
            "pc": 1
        },
        {
            "members": [member(0, 0.2, false, "headphones", "Studio headphones"), member(1, 0.2, false, "speaker", "Desk speaker"), member(2, 0.2, false, "earbuds", "Earbuds")],
            "pc": 0.3
        },
        {
            "members": [],
            "device": 0.62,
            "pc": 0.85
        },
        {
            "members": [],
            "device": -1,
            "pc": 0.85
        }
    ]

    Grid {
        x: 16
        y: 16
        columns: 2
        spacing: 16
        Repeater {
            model: win.cases
            // The island's glass: flat corners against the screen edge
            Rectangle {
                id: sheet
                required property var modelData
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
                    showFacts: false
                    overlay: FakeOverlay {
                        style: win.style
                        members: sheet.modelData.members
                        deviceLevel: sheet.modelData.device === undefined ? -1 : sheet.modelData.device
                        pcLevel: sheet.modelData.pc
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
