import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Modules.Plugins
import "components"

// Desktop surface: a frameless orbit that dissolves into the wallpaper.
// Idle by default: the scene freezes (zero frames) until the pointer is over
// it, chrome only appears while in use, and scanning only runs meanwhile.
DesktopPluginComponent {
    id: root

    minWidth: 300
    minHeight: 240
    property real defaultWidth: 440
    property real defaultHeight: 380

    readonly property bool hot: hover.hovered
    // Keeps discovery alive a little after the pointer leaves
    property bool lingering: false

    onHotChanged: {
        if (hot) {
            lingerTimer.stop();
            dismissTimer.stop();
            lingering = true;
        } else {
            lingerTimer.restart();
            if (scene.focusBody || scene.hiddenOpen || scene.menuOpen)
                dismissTimer.restart();
        }
    }

    // A desktop layer never sees clicks made elsewhere, so the detail card,
    // the black hole's list and the device menu close when the pointer
    // leaves for good or another window takes focus.
    Timer {
        id: dismissTimer
        interval: 1200
        onTriggered: scene.dismiss()
    }

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            if (ToplevelManager.activeToplevel)
                scene.dismiss();
        }
    }

    Timer {
        id: lingerTimer
        interval: 20000
        onTriggered: root.lingering = false
    }

    HoverHandler {
        id: hover
    }

    OrbitScene {
        id: scene
        anchors.fill: parent
        glass: true
        active: true
        autoScan: root.lingering
        freezeWhenIdle: true
        interacting: root.hot
    }
}
