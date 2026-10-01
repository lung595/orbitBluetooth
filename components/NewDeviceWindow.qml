import QtQuick
import Quickshell
import Quickshell.Wayland
import "DeviceCatalog.js" as Catalog
import "Offer.js" as Offer
import "Pictures.js" as Pictures

// The window of the "new device" pop-up: a transparent overlay layer at
// the top of the screen, under the bar, that only takes clicks on the card.
// NewDeviceWatch creates it while there is something to offer.
PanelWindow {
    id: win

    required property var watch

    screen: watch._screen
    anchors.top: true
    color: "transparent"
    implicitWidth: popup.implicitWidth
    implicitHeight: popup.implicitHeight
    // Below the bar (it keeps its exclusive zone), above windows
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dms:plugins:orbitBluetooth:newDevice"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Clicks around the card reach the windows below
    mask: Region {
        item: popup.card
    }

    NewDevicePopup {
        id: popup
        anchors.fill: parent
        shown: win.watch.shown
        phase: win.watch.phase
        reduceMotion: win.watch.prefs.reduceMotion
        name: Catalog.deviceName(win.watch.device)
        kind: Catalog.resolve(win.watch.device, ({}))
        headline: Offer.headline(kind)
        pictureSource: win.watch.picture ? win.watch.picture.image : ""
        credit: win.watch.picture ? Pictures.creditText(win.watch.picture.credit) : ""
        battery: win.watch.device && win.watch.device.batteryAvailable ? Math.round(win.watch.device.battery * 100) : -1

        onAccepted: win.watch.connect()
        onRetry: win.watch.connect()
        onLater: win.watch.phase === "done" ? win.watch.close() : win.watch.later()
        onIgnored: win.watch.ignore()
        onCancelled: win.watch.cancel()

        // Runs down while nobody answers; paused under the pointer
        NumberAnimation on life {
            running: win.watch.shown && win.watch.phase === "offer"
            paused: running && popup.hovered
            from: 1
            to: 0
            duration: 20000
            onFinished: if (win.watch.phase === "offer")
                win.watch.later()
        }
    }
}
