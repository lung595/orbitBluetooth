import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Modules.Plugins
import qs.Services
import "components/scene"
import "components/scene/Cover.js" as Cover
import "diagnostics/Log.js" as Log

// Desktop surface: a frameless orbit that dissolves into the wallpaper.
// Idle by default: the scene freezes (zero frames) until the pointer is over
// it, chrome only appears while in use, and scanning only runs meanwhile.
DesktopPluginComponent {
    id: root

    // One memory write each way: which surfaces are alive shows in a report
    Component.onCompleted: Log.event("ORB-I020", {
        "surface": "desktop"
    })
    Component.onDestruction: Log.event("ORB-I021", {
        "surface": "desktop"
    })

    minWidth: 300
    minHeight: 240
    property real defaultWidth: 440
    property real defaultHeight: 380

    readonly property bool hot: hover.hovered
    // A desktop layer gets no keyboard by default. DMS can give it on demand,
    // but the compositor hands it over on a click and only if the mode is
    // already on when the click lands: so it is on while the pointer is over the
    // widget (the press that opens a menu then takes it, and Escape closes the
    // menu), and while a card, a menu or the hidden list is open (the name can be
    // typed with the pointer away). It drops with the pointer, which gives the
    // keyboard back to the window that had it.
    readonly property bool acceptsKeyboardFocus: hot || scene.cardOpen || scene.menuOpen
    // Keeps discovery alive a little after the pointer leaves
    property bool lingering: false
    // Set by DMS's desktop wrapper: the screen this copy of the widget is on
    property var screen: null
    // Behind windows that fill the screen (fullscreen, maximized or side by
    // side) nobody sees the drift, so Ambient motion pauses there and the
    // scene draws nothing (niri only; elsewhere it never pauses).
    readonly property bool covered: CompositorService.isNiri && !!screen && Cover.covered(NiriService.workspaces, NiriService.windows, screen.name, screen.width, screen.height, NiriService.inOverview)

    onHotChanged: {
        if (hot) {
            lingerTimer.stop();
            dismissTimer.stop();
            lingering = true;
        } else {
            lingerTimer.restart();
            if (scene.cardOpen || scene.menuOpen)
                dismissTimer.restart();
        }
    }

    // A desktop layer never sees clicks made elsewhere, so the detail card,
    // the black hole's list and the device menu close when the pointer
    // leaves for good or another window takes focus.
    Timer {
        id: dismissTimer
        interval: 1200
        onTriggered: {
            // Typing a new name: the pointer may be elsewhere
            if (!scene.renaming)
                scene.dismiss();
        }
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
        covered: root.covered
        interacting: root.hot
    }
}
