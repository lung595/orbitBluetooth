import QtQuick
import qs.Common

// The vectorscope on its own dark screen (D262), as the volume pop-up and
// the Dank Island sheet both show it: DMS's themed frame around it is the
// caller's, Orbit's night sky is inside. Nothing here runs unless `live`.
Item {
    id: screenItem

    // VolumeOverlay: the levels to show, what to do with a gesture
    required property var overlay
    property bool live: false
    // Drawn lying flat, turned upright on a side (Route.popupLayout)
    property bool upright: false
    property real turn: 0

    // A gesture: the caller keeps itself open a while longer
    signal touched
    readonly property bool hovered: scope.hovered

    readonly property NightColors night: NightColors {}

    function wake() {
        scope.wake();
    }

    Rectangle {
        id: screen
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        radius: Math.max(0, Theme.cornerRadius - Theme.spacingS)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.tint(screenItem.night.sky, Theme.withAlpha(screenItem.night.tertiary, 0.05))
            }
            GradientStop {
                position: 1
                color: Qt.tint(screenItem.night.skyDeep, Theme.withAlpha(screenItem.night.primary, 0.06))
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
        deviceColor: screenItem.night.primary
        pcColor: screenItem.night.tertiary
        trackColor: screenItem.night.ink(0.14)
        inkColor: screenItem.night.ink(0.92)
        mutedColor: screenItem.night.ink(0.4)
        hollowColor: screenItem.night.sky

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
        onMuteClicked: part => {
            screenItem.overlay.toggleMute(part);
            screenItem.touched();
        }
    }
    onLiveChanged: if (live)
        scope.wake()
}
