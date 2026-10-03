import QtQuick
import qs.Common

// The vectorscope on its own screen (D262, D263), as the volume pop-up and
// the Dank Island sheet both show it: DMS's themed frame around it is the
// caller's, Orbit's screen is inside. Dark theme: a night screen with
// additive light, like a lit phosphor. Light theme: soft paper with the
// theme's own accents drawn over it (light added to paper would vanish).
// Nothing here runs unless `live`.
Item {
    id: screenItem

    // VolumeOverlay: the levels to show, what to do with a gesture
    required property var overlay
    property bool live: false
    // Drawn lying flat, turned upright on a side (Route.popupLayout)
    property bool upright: false
    property real turn: 0
    // The frame's own corners (top-left, top-right, bottom-left,
    // bottom-right): the screen's corners run parallel to them
    property var radii: [Theme.cornerRadius, Theme.cornerRadius, Theme.cornerRadius, Theme.cornerRadius]
    readonly property real margin: Theme.spacingS

    // A gesture: the caller keeps itself open a while longer
    signal touched
    readonly property bool hovered: scope.hovered

    readonly property NightColors night: NightColors {}
    readonly property PaperColors paper: PaperColors {}
    readonly property bool light: Theme.isLightMode
    function _inner(r) {
        return Math.max(0, (r || 0) - margin);
    }

    function wake() {
        scope.wake();
    }
    // Fills the picture from a made-up frame (previews)
    function simulate(frame, seconds) {
        scope.simulate(frame, seconds);
    }

    Rectangle {
        id: screen
        anchors.fill: parent
        anchors.margins: screenItem.margin
        topLeftRadius: screenItem._inner(screenItem.radii[0])
        topRightRadius: screenItem._inner(screenItem.radii[1])
        bottomLeftRadius: screenItem._inner(screenItem.radii[2])
        bottomRightRadius: screenItem._inner(screenItem.radii[3])
        gradient: Gradient {
            GradientStop {
                position: 0
                color: screenItem.light ? Qt.tint(screenItem.paper.fill(0.92), Theme.withAlpha(Theme.tertiary, 0.04)) : Qt.tint(screenItem.night.sky, Theme.withAlpha(screenItem.night.tertiary, 0.05))
            }
            GradientStop {
                position: 1
                color: screenItem.light ? Qt.tint(Qt.darker(screenItem.paper.fill(0.92), 1.04), Theme.withAlpha(Theme.primary, 0.06)) : Qt.tint(screenItem.night.skyDeep, Theme.withAlpha(screenItem.night.primary, 0.06))
            }
        }
    }

    PolarScope {
        id: scope
        anchors.centerIn: screen
        width: (screenItem.upright ? screen.height : screen.width) - Theme.spacingXS * 2
        height: (screenItem.upright ? screen.width : screen.height) - Theme.spacingXS * 2
        rotation: screenItem.turn

        style: screenItem.overlay.style
        grid: true
        additive: !screenItem.light
        deviceColor: screenItem.light ? Theme.primary : screenItem.night.primary
        pcColor: screenItem.light ? Theme.tertiary : screenItem.night.tertiary
        trackColor: screenItem.light ? screenItem.paper.fg(0.16) : screenItem.night.ink(0.14)
        inkColor: screenItem.light ? screenItem.paper.ink : screenItem.night.ink(0.92)
        mutedColor: screenItem.light ? screenItem.paper.fg(0.42) : screenItem.night.ink(0.4)
        hollowColor: screenItem.light ? screenItem.paper.fill(0.92) : screenItem.night.sky

        deviceLevel: screenItem.overlay.deviceLevel
        pcLevel: screenItem.overlay.pcLevel
        deviceMuted: screenItem.overlay.deviceMuted
        pcMuted: screenItem.overlay.pcMuted
        deviceIcon: screenItem.overlay.deviceIcon
        pcIcon: screenItem.overlay.pcIcon
        feed: screenItem.overlay.feed
        live: screenItem.live
        motion: !screenItem.overlay.reduceMotion
        fps: screenItem.overlay.fps

        onMoved: (part, level) => {
            screenItem.overlay.setLevel(part, level);
            screenItem.touched();
        }
        smartWheel: true
        numbers: true
        deviceLabel: screenItem.overlay.deviceName || "Device"
        onStepped: (part, dir) => {
            screenItem.overlay.stepLevel(part, dir);
            screenItem.touched();
        }
        onMuteClicked: part => {
            screenItem.overlay.toggleMute(part);
            screenItem.touched();
        }
    }
    onLiveChanged: if (live)
        scope.wake()
}
