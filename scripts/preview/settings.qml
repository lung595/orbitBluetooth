import QtQuick
import QtQuick.Window
import qs.Common
import "../.."

// Offscreen renders of the real settings page (rail, search, pages) with
// stand-ins for DMS's setting widgets and made-up values.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports settings.qml -- <state> <out.png>
// States: default, category (Pop-up open), search ("tick"), jump (Enter on "tick":
//         the volume tick lit), none (nothing matches), many (Audio details,
//         20 switches); suffixes: -light, -narrow, -reduce
Window {
    id: win
    readonly property var opts: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property var parts: opts[0].split("-")
    readonly property string state: parts[0]
    readonly property string out: opts[1]
    readonly property bool narrow: parts.indexOf("narrow") > 0
    readonly property bool light: parts.indexOf("light") > 0
    // The jump stays lit only with Reduce motion: the fade is not a still image
    readonly property bool reduce: parts.indexOf("reduce") > 0 || state === "jump"

    // 550 px is the width of the plugin page in DMS, 328 a small window's
    width: narrow ? 328 : 550 + Theme.spacingL * 2
    height: state === "many" ? 960 : 640
    visible: true

    // The search field is the item that holds the view; no private name is needed
    function findField(item) {
        if (item.focusField && item.view)
            return item;
        for (const child of item.children) {
            const found = findField(child);
            if (found)
                return found;
        }
        return null;
    }

    Component.onCompleted: {
        if (light) {
            Theme.isLightMode = true;
            Theme.primary = "#4B6818";
            Theme.primaryText = "#FFFFFF";
            Theme.surface = "#FAFAF2";
            Theme.surfaceContainer = "#EEEFE6";
            Theme.surfaceContainerHigh = "#E8E9E0";
            Theme.surfaceContainerHighest = "#E2E3DA";
            Theme.outline = "#75786B";
            Theme.surfaceText = "#1A1C16";
            Theme.surfaceVariantText = "#44483B";
        }
        SettingsData.reduceMotion = reduce;
        drive.start();
    }

    // The picture is taken from the content, which has no background of its own
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }
    Item {
        x: Theme.spacingL
        y: Theme.spacingL
        width: parent.width - Theme.spacingL * 2
        height: parent.height - Theme.spacingL * 2
        OrbitBluetoothSettings {
            id: page
            width: parent.width
        }
    }

    Timer {
        id: drive
        interval: 400
        onTriggered: {
            const view = win.findField(page).view;
            if (win.state === "category")
                view.open("popup", "");
            else if (win.state === "many")
                view.open("audio", "");
            else if (win.state === "search")
                view.query = "tick";
            else if (win.state === "none")
                view.query = "xylophone synth";
            else if (win.state === "jump") {
                view.query = "tick";
                view.openFirst();
            }
            snap.start();
        }
    }
    Timer {
        id: snap
        interval: 900
        onTriggered: win.contentItem.grabToImage(r => {
            r.saveToFile(win.out);
            Qt.quit();
        })
    }
}
