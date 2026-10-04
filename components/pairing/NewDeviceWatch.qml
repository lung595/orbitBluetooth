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

    function _family(d) {
        return Catalog.families[Catalog.resolve(d, ({}))] || "";
    }

    // --- The pop-up --------------------------------------------------------------
    property string current: ""
    // "offer", "pairing", "connecting", "done" or "failed"
    property string phase: "offer"
    property bool shown: false
    property var _screen: null
    // Why the last pairing failed (newDeviceStatus), "" otherwise
    property string lastError: ""
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

    Timer {
        id: demoStep
        interval: 1100
        onTriggered: {
            if (root.phase === "pairing") {
                // The demo has no real device to check: it moves on itself
                root.demoDevice.paired = true;
                root.phase = "connecting";
                restart();
            } else if (root.phase === "connecting") {
                root.demoDevice.connected = true;
            }
        }
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
        phase = "offer";
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
        _dropUnconfirmed();
        shown = false;
        connectTimeout.stop();
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

    // Same path as dragging a device into the orbit (OrbitScene.startConnect)
    function connect() {
        const d = device;
        if (!d)
            return;
        const address = current;
        lastError = "";
        connectTimeout.restart();
        _checked = false;
        if (_demo) {
            phase = "pairing";
            demoStep.restart();
            return;
        }
        if (d.paired || d.bonded) {
            // Paired before, from here or DMS: the user already chose it
            _checked = true;
            phase = "connecting";
            BluetoothService.connectDeviceWithTrust(d);
            return;
        }
        phase = "pairing";
        BluetoothService.pairDevice(d, res => {
            if (root.current !== address || (root.phase !== "pairing" && root.phase !== "connecting"))
                return;
            if (res && res.error) {
                root.lastError = String(res.error);
                // A fixed line: the error text may carry a device name or address (value 11)
                console.warn("orbitBluetooth: pairing failed while " + root.phase);
                root.phase = "failed";
                connectTimeout.stop();
                return;
            }
            root._checkThenConnect(d, address);
        });
    }

    // Trust only after checking it cannot also type (P115)
    function _checkThenConnect(d, address) {
        profileCheck.check(d, _family(d), verdict => {
            if (root.current !== address)
                return;
            if (verdict === "input") {
                // Blocked by ProfileCheck until the user answers in the sheet
                root.phase = "confirm";
                connectTimeout.stop();
            } else if (verdict === "refused") {
                root.lastError = "could not check";
                root.phase = "failed";
                connectTimeout.stop();
            } else if (root.phase === "pairing" || root.phase === "confirm") {
                root.phase = "connecting";
                if (d.connected)
                    root._connected();
                else
                    BluetoothService.connectDeviceWithTrust(d);
            } else if (root.phase === "done") {
                root._checked = true;
            }
        });
    }

    // "Pair anyway": the user knows this headset sends its buttons as keys
    function confirmInput() {
        const d = device;
        if (phase !== "confirm" || !d)
            return;
        profileCheck.allow(d);
        _checked = true;
        phase = "connecting";
        connectTimeout.restart();
        BluetoothService.connectDeviceWithTrust(d);
    }

    // Leaving the question unanswered means no: the device is forgotten
    function _dropUnconfirmed() {
        if (phase === "confirm" && device && !_demo)
            profileCheck.deny(device);
    }

    function cancel() {
        demoStep.stop();
        _dropUnconfirmed();
        const d = device;
        if (d) {
            if (d.pairing)
                d.cancelPair();
            d.disconnect();
        }
        later();
    }

    // Connected after the check: Bluetooth LE lists its profiles only once
    // connected, so look once more (it may still turn out to type)
    property bool _checked: false
    function _connected() {
        phase = "done";
        connectTimeout.stop();
        if (!_checked && !_demo)
            _checkThenConnect(device, current);
        // The name typed in the sheet becomes the BlueZ alias, like a
        // rename in the detail card
        if (pendingName && pendingName !== Catalog.deviceName(device))
            device.name = pendingName;
        // Ask the headset for its modes, for the selector in the sheet
        if (anc && !_demo && Anc.family(Catalog.modelName(device))) {
            anc.watch(current, true);
            _ancWatching = true;
        }
    }

    Connections {
        target: root.device
        function onConnectedChanged() {
            if (root.device.connected && root.phase === "connecting")
                root._connected();
        }
        // Stay in "pairing" until ProfileCheck has run: it moves to "connecting"
        function onPairedChanged() {
        }
    }

    // Pairing waits for the user in DMS's pairing dialog: be patient
    Timer {
        id: connectTimeout
        interval: 45000
        onTriggered: if (root.phase === "pairing" || root.phase === "connecting") {
            root.lastError = "timed out in " + root.phase;
            root.phase = "failed";
        }
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

    ProfileCheck {
        id: profileCheck
    }
}
