import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import "Route.js" as Route

// The volume pop-up on one screen (D252, D258): DMS's own OSD window
// (DankOSD: same glass, shadow, spring and auto-hide), holding the polar
// vectorscope. Showing it registers it with DMS's OSDManager, which keeps
// one OSD per screen: DMS's volume OSD steps aside by itself, and none of
// DMS's settings is written (value 12, D259).
// The content (and the vectorscope's clock) only exists while it shows.
DankOSD {
    id: popup

    // VolumeOverlay: the levels to show, what to do with a gesture
    required property var overlay

    readonly property var layout: Route.popupLayout(overlay.mode, isVerticalLayout, SettingsData.osdPosition === SettingsData.Position.LeftCenter, overlay.size)

    blurNamespace: "dms:plugins:orbitBluetooth:volume"
    osdWidth: Math.min(layout.w, screenWidth - Theme.spacingM * 2)
    osdHeight: Math.min(layout.h, screenHeight - Theme.spacingM * 2)
    autoHideInterval: 3000
    enableMouseInteraction: true

    // Where it stands: DMS's own OSD place, under the bar widget (the right
    // end of the bar, like the pairing sheet) or on the right screen edge
    readonly property var barConfig: SettingsData.getPrimaryBarConfig()
    readonly property int barSide: barConfig?.position ?? SettingsData.Position.Top
    readonly property real gap: Theme.spacingS
    readonly property real rightX: screenWidth - alignedWidth - Math.max(gap, barEdgeOffsets.right + gap)
    readonly property real placeX: {
        if (overlay.mode === "bar")
            return barSide === SettingsData.Position.Left ? barEdgeOffsets.left + gap : rightX;
        if (overlay.mode === "edge")
            return screenWidth - alignedWidth - Theme.spacingM - barEdgeOffsets.right;
        return alignedX;
    }
    readonly property real placeY: {
        if (overlay.mode === "bar")
            return barSide === SettingsData.Position.Bottom ? screenHeight - alignedHeight - barEdgeOffsets.bottom - gap : barEdgeOffsets.top + gap;
        if (overlay.mode === "edge")
            return (screenHeight - alignedHeight) / 2;
        return alignedY;
    }
    WlrLayershell.margins.left: Math.max(0, Theme.snap(placeX - shadowBuffer, dpr))
    WlrLayershell.margins.top: Math.max(0, Theme.snap(placeY - shadowBuffer, dpr))

    readonly property NightColors night: NightColors {}

    content: Item {
        anchors.fill: parent

        // A click beside the arcs and icons closes it, as DMS's OSD does
        MouseArea {
            anchors.fill: parent
            onClicked: popup.hide()
        }

        // The scope's own screen: dark in every theme, set inside DMS's
        // themed frame like Orbit's sky in its pop-out
        Rectangle {
            id: screen
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            radius: Math.max(0, Theme.cornerRadius - Theme.spacingS)
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.tint(popup.night.sky, Theme.withAlpha(popup.night.tertiary, 0.05))
                }
                GradientStop {
                    position: 1
                    color: Qt.tint(popup.night.skyDeep, Theme.withAlpha(popup.night.primary, 0.06))
                }
            }
        }

        PolarScope {
            id: scope
            // Drawn lying flat, then turned upright on a side
            anchors.centerIn: screen
            width: (popup.layout.upright ? screen.height : screen.width) - Theme.spacingXS * 2
            height: (popup.layout.upright ? screen.width : screen.height) - Theme.spacingXS * 2
            rotation: popup.layout.rotation

            style: popup.overlay.style
            grid: true
            deviceColor: popup.night.primary
            pcColor: popup.night.tertiary
            trackColor: popup.night.ink(0.14)
            inkColor: popup.night.ink(0.92)
            mutedColor: popup.night.ink(0.4)
            hollowColor: popup.night.sky

            deviceLevel: popup.overlay.deviceLevel
            pcLevel: popup.overlay.pcLevel
            deviceMuted: popup.overlay.deviceMuted
            pcMuted: popup.overlay.pcMuted
            deviceIcon: popup.overlay.deviceIcon
            pcIcon: popup.overlay.pcIcon
            feed: popup.overlay.feed
            live: popup.shouldBeVisible
            motion: !popup.overlay.reduceMotion
            fps: popup.overlay.fps

            onMoved: (part, level) => {
                popup.overlay.setLevel(part, level);
                popup.resetHideTimer();
            }
            onMuteClicked: part => {
                popup.overlay.toggleMute(part);
                popup.resetHideTimer();
            }
            // The pointer over it keeps it open
            onHoveredChanged: popup.setChildHovered(hovered)
            Component.onCompleted: wake()
        }
    }
}
