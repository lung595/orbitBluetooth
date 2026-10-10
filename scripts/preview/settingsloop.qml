import QtQuick
import QtQuick.Window
import qs.Common
import "../.."

// Bench scene for the settings page; runs until stopped.
// Usage: qml -I imports -I ../../tests/qml/stubs settingsloop.qml -- <mode> /dev/null
// Modes: idle (page built once, nothing happens), open (page destroyed and
//        rebuilt every 1.5 s), type (query typed and cleared in a loop; needs
//        the search view), jump (query + Enter in a loop; needs the search view)
Window {
    id: win
    readonly property var opts: Qt.application.arguments.slice(Qt.application.arguments.indexOf("--") + 1)
    readonly property string mode: opts[0]
    readonly property var words: ["t", "ti", "tic", "tick", "tick v", "tick vo", "", "dev", "devi", ""]
    property int step: 0
    width: 550 + Theme.spacingL * 2
    height: 640
    visible: true

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

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }
    Loader {
        id: loader
        x: Theme.spacingL
        y: Theme.spacingL
        width: parent.width - Theme.spacingL * 2
        active: true
        sourceComponent: OrbitBluetoothSettings {}
    }
    Timer {
        interval: win.mode === "open" ? 1500 : win.mode === "idle" ? 3600000 : 120
        running: true
        repeat: true
        onTriggered: {
            if (win.mode === "open") {
                loader.active = !loader.active;
                return;
            }
            const f = loader.item ? win.findField(loader.item) : null;
            if (!f)
                return;
            if (win.mode === "type")
                f.view.query = win.words[win.step++ % win.words.length];
            else if (win.mode === "jump") {
                f.view.query = "tick";
                f.view.openFirst();
                f.view.query = "";
            }
        }
    }
}
