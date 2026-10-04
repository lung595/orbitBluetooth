import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import qs.Services
import "../device/DeviceCatalog.js" as Catalog
import "../common/Pictures.js" as Pictures
import "../noise/Anc.js" as Anc

// "New device nearby" pop-up. Lives in the daemon, so it works while every
// Orbit view is closed:
// - it listens to every scan, whoever starts it (DMS's Bluetooth panel,
//   system settings, an Orbit view): that costs nothing;
// - its own short background scan every minute or so is opt-in (P103,
//   BackgroundScan);
// - a named, unpaired audio device that shows up (OfferQueue) is offered in a sheet
//   under the right end of the bar (PairingSheet), never while a window
//   is full screen; "Later" snoozes it, "Ignore" never offers it again;
// - Connect pairs and connects it right there, and shows the battery.
// Nothing leaves the machine, except the model name when the user turned
// "Real device pictures" on (see Pictures.js).
// The idea comes from the nearby-device cards of Google Fast Pair and of
// Apple's AirPods setup; thanks to them. Only the idea: this is plain BlueZ
// discovery, no vendor protocol.
Item {
    id: root

    required property var prefs
    // PictureService of the daemon (lookups and the model -> picture map)
    property var pictureLookup: null
    // AncService of the daemon: noise-control modes once connected
    property var anc: null

    // The pop-up has its own switch: "Offer new devices" is only the card
    // inside the Orbit view (OrbitScene), turning it off must not hide this
    readonly property bool offering: prefs.offerPopup
    readonly property var adapter: BluetoothService.adapter
    readonly property bool btOn: BluetoothService.enabled
    readonly property bool asleep: SessionService.locked || IdleService.isShellLocked || IdleService.monitorsOff
    readonly property bool fullscreen: ToplevelManager.activeToplevel?.fullscreen ?? false

    // Why the last background scan was skipped ("" when it ran), shown by the newDeviceStatus IPC call
    property alias lastSkip: scan.lastSkip

    // --- Background scan ---------------------------------------------------------
    function holdScan(on) {
        scan.holdScan(on);
    }
    function scanOnce() {
        scan.scanOnce();
    }

    BackgroundScan {
        id: scan
        prefs: root.prefs
        offering: root.offering
        btOn: root.btOn
        asleep: root.asleep
        adapter: root.adapter
    }

    onOfferingChanged: if (!offering)
        scan.stop()
    onAsleepChanged: {
        if (asleep)
            scan.stop();
        else
            _showNext();
    }
    onFullscreenChanged: if (!fullscreen)
        _showNext()

    // --- What to offer -------------------------------------------------------------
    readonly property alias offers: offers
    OfferQueue {
        id: offers
        prefs: root.prefs
        offering: root.offering
        adapter: root.adapter
        current: root.current
        onQueued: root._showNext()
    }

    // --- The pop-up --------------------------------------------------------------
    property string current: ""
    // The pairing steps (PairingFlow): "offer", "pairing", "confirm", "connecting", "done" or "failed"
    property alias phase: flow.phase
    property bool shown: false
    property var _screen: null
    // Why the last pairing failed (newDeviceStatus), "" otherwise
    property alias lastError: flow.lastError
    // A name typed in the sheet before connecting, applied once connected
    property string pendingName: ""
    // The pointer is over the sheet (set by NewDeviceWindow): nothing closes meanwhile
    property bool hovered: false
    // Noise control of the connected headset, once the sheet asked for it
    property bool _ancWatching: false
    readonly property var ancInfo: anc && current && !_demo ? (anc.snapshots[current] || null) : null
    readonly property var device: _demo ? demoDevice : current ? offers.deviceFor(current) : null
    // Only for a device that is paired with this computer: one merely seen
    // in pairing mode may be a stranger's, and its name is not ours to send
    readonly property string query: prefs.realPictures && device && (device.paired || device.bonded) ? Pictures.queryFor(Catalog.modelName(device), true) : ""
    // Asked once the device pairs (and again if the sheet moves to another)
    onQueryChanged: {
        if (query && pictureLookup)
            pictureLookup.request(query);
    }
    readonly property var picture: query && pictureLookup ? (pictureLookup.pictures[query] || null) : null

    // --- Demo (dms ipc call orbitBluetooth newDeviceDemo) ---------------------
    // The whole story with a made-up headset, to see the pop-up without
    // buying one. Nothing is paired, nothing is saved.
    property bool _demo: false
    readonly property QtObject demoDevice: DemoDevice {}

    function demo() {
        if (current)
            return "A pop-up is already shown";
        _demo = true;
        demoDevice.paired = false;
        demoDevice.connected = false;
        _openOn("demo");
        return "OK";
    }

    function _showNext() {
        if (current || asleep || fullscreen)
            return;
        const address = offers.take();
        if (address)
            _openOn(address);
    }

    // The sheet for `address`, on the screen being looked at (the one of the
    // active window). Mapped first, then shown: the entrance animates from the bar
    function _openOn(address) {
        const top = ToplevelManager.activeToplevel;
        _screen = top && top.screens && top.screens.length ? top.screens[0] : Quickshell.screens[0];
        flow.reset();
        pendingName = "";
        current = address;
        showDelay.restart();
    }

    Timer {
        id: showDelay
        interval: 80
        onTriggered: root.shown = true
    }

    function close() {
        flow.release();
        shown = false;
        if (_ancWatching && anc)
            anc.watch(current, false);
        _ancWatching = false;
        hideDelay.restart();
    }

    function setMode(mode) {
        if (anc && current && !_demo)
            anc.send(current, "mode", mode);
    }

    Timer {
        id: hideDelay
        interval: 420
        onTriggered: {
            root.current = "";
            root._demo = false;
            root._showNext();
        }
    }

    function later() {
        if (current && !_demo)
            offers.snooze(current);
        close();
    }

    function ignore() {
        if (current && !_demo)
            prefs.setIgnored(current, Catalog.deviceName(device), true);
        close();
    }

    PairingFlow {
        id: flow
        current: root.current
        device: root.device
        demo: root._demo
        demoDevice: root.demoDevice
        onArrived: {
            // The name typed in the sheet becomes the BlueZ alias, like a
            // rename in the detail card
            if (root.pendingName && root.pendingName !== Catalog.deviceName(root.device))
                root.device.name = root.pendingName;
            // Ask the headset for its modes, for the selector in the sheet
            if (root.anc && !root._demo && Anc.family(Catalog.modelName(root.device))) {
                root.anc.watch(root.current, true);
                root._ancWatching = true;
            }
        }
    }

    function connect() {
        flow.connect();
    }
    function confirmInput() {
        flow.confirmInput();
    }

    function cancel() {
        flow.abort();
        later();
    }

    // Long enough to read the battery and pick a mode, then it folds back
    // into the bar; never while the pointer is over it
    Timer {
        interval: 6000
        running: root.phase === "done" && root.shown && !root.hovered
        onTriggered: root.close()
    }

    LazyLoader {
        active: root.current !== ""

        NewDeviceWindow {
            watch: root
        }
    }

    Component.onDestruction: scan.stop()
}
