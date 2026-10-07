import QtQuick
import Quickshell.Wayland
import qs.Common
import qs.Widgets
import "Route.js" as Route

// The volume pop-up on one screen (D252, D258): DMS's own OSD window
// (DankOSD: same glass, shadow, spring and auto-hide), holding the polar
// vectorscope. Showing it registers it with DMS's OSDManager, which keeps
// one OSD per screen: another OSD (brightness, microphone) steps aside by
// itself. DMS's volume OSD is already off (DmsQuiet, D273).
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

    content: Item {
        anchors.fill: parent

        // A click beside the arcs and icons closes it, as DMS's OSD does
        MouseArea {
            anchors.fill: parent
            onClicked: popup.hide()
        }

        ScopeScreen {
            anchors.fill: parent
            overlay: popup.overlay
            live: popup.shouldBeVisible
            upright: popup.layout.upright
            turn: popup.layout.rotation
            onTouched: popup.resetHideTimer()
            // The pointer over it keeps it open
            onHoveredChanged: popup.setChildHovered(hovered)
        }
    }
}
