import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import "DeviceCatalog.js" as Catalog
import "Offer.js" as Offer
import "Pictures.js" as Pictures
import "Anc.js" as Anc
import "Endurance.js" as Endurance
import "Glyphs.js" as Glyphs

// The window of the pairing sheet: a transparent overlay layer under the
// right end of the bar, that only takes clicks on the card. NewDeviceWatch
// creates it while there is something to offer.
PanelWindow {
    id: win

    required property var watch

    readonly property var device: watch.device
    readonly property string model: Catalog.modelName(device)
    readonly property string kind: Catalog.resolve(device, ({}))
    readonly property string family: Anc.family(model)

    // Rated hours only for models Orbit knows; a guess by type would mislead here
    function knownHours(name) {
        for (let i = 0; i < Endurance.MODELS.length; i++)
            if (Endurance.MODELS[i][0].test(name || ""))
                return Endurance.MODELS[i][1];
        return 0;
    }

    // Short labels: the selected mode shows its name inside a pill
    readonly property var shortLabels: ({
            "nc": "ANC",
            "adaptive": "Auto",
            "ambient": "Ambient",
            "off": "Off"
        })

    screen: watch._screen
    // Under the right end of the bar: the card's edge lines up with the
    // screen edge the bar's last widget sits against (the sheet keeps a thin
    // margin of its own for the shadow)
    anchors.top: true
    anchors.right: true
    color: "transparent"
    implicitWidth: sheet.implicitWidth
    implicitHeight: sheet.implicitHeight
    // Below the bar (it keeps its exclusive zone), above windows
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dms:plugins:orbitBluetooth:newDevice"
    // The keyboard once the sheet is clicked (Enter, Escape, typing a name),
    // never on its own: it does not steal keys from the window in use. Fixed
    // on purpose: switching it as the pointer came and went made the
    // compositor reconfigure the surface under the pointer, and clicks on
    // Connect were lost.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Clicks around the card reach the windows below
    mask: Region {
        item: sheet.hitArea
    }

    Binding {
        target: win.watch
        property: "hovered"
        value: sheet.hovered
    }

    PairingSheet {
        id: sheet
        anchors.fill: parent
        shown: win.watch.shown
        asleep: win.watch.asleep
        phase: win.watch.phase
        reduceMotion: win.watch.prefs.reduceMotion
        exitToBar: win.watch.phase === "done"
        stacked: win.watch._queue.length
        // Line up with the bar: its gap to the screen edge when DMS has one
        rightGap: typeof SettingsData.dankBarSpacing === "number" ? Math.max(2, SettingsData.dankBarSpacing) : Theme.spacingXS
        topGap: Theme.spacingS
        errorText: Offer.errorText(win.watch.lastError)
        name: win.watch.pendingName || Catalog.deviceName(win.device)
        subtitle: [Offer.BRANDS[win.family] || "", Glyphs.label(win.kind)].filter(x => x).join(" · ")
        kind: win.kind
        features: Offer.features({
            "family": win.family,
            "hours": win.knownHours(win.model),
            "kind": win.kind
        })
        pictureSource: win.watch.picture ? win.watch.picture.image : ""
        credit: win.watch.picture ? Pictures.creditText(win.watch.picture.credit) : ""
        battery: win.device && win.device.batteryAvailable ? Math.round(win.device.battery * 100) : -1
        ancModes: {
            const modes = win.watch.ancInfo?.features?.modes ?? [];
            return Anc.ordered(modes).map(m => ({
                        "id": m,
                        "icon": Anc.ICONS[m] || "tune",
                        "label": win.shortLabels[m] || m
                    }));
        }
        ancMode: win.watch.ancInfo?.state?.mode ?? ""

        onAccepted: {
            sheet.forceActiveFocus();
            win.watch.connect();
        }
        onRetry: win.watch.connect()
        onLater: win.watch.phase === "done" ? win.watch.close() : win.watch.later()
        onIgnored: win.watch.ignore()
        onCancelled: win.watch.cancel()
        onRenamed: text => win.watch.pendingName = text
        onModeRequested: mode => win.watch.setMode(mode)

        // Runs down while nobody answers; paused under the pointer
        NumberAnimation on life {
            running: win.watch.shown && win.watch.phase === "offer"
            paused: running && sheet.hovered
            from: 1
            to: 0
            duration: 30000
            onFinished: if (win.watch.phase === "offer")
                win.watch.later()
        }
    }

    // Arrival, success and failure cues, when Orbit's sounds are on
    SoundFx {
        id: sounds
        enabled: win.watch.prefs.sounds
        volume: win.watch.prefs.soundVolume
    }
    Connections {
        target: win.watch
        function onShownChanged() {
            if (win.watch.shown)
                sounds.play("snap");
        }
        function onPhaseChanged() {
            if (win.watch.phase === "done")
                sounds.play("connect");
            else if (win.watch.phase === "failed")
                sounds.play("error");
        }
    }
}
