import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.Services
import "DeviceCatalog.js" as Catalog
import "Offer.js" as Offer
import "Guard.js" as Guard
import "Pictures.js" as Pictures
import "Anc.js" as Anc

// "New device nearby" pop-up. Lives in the daemon, so it works while every
// Orbit view is closed:
// - it listens to every scan, whoever starts it (DMS's Bluetooth panel,
//   system settings, an Orbit view): that costs nothing;
// - its own short background scan every minute or so is opt-in (P103),
//   and even then only runs while it is cheap and harmless: Bluetooth on, screen awake, no Bluetooth audio
//   playing (discovery makes it stutter), battery above the chosen level
//   (Offer.scanBlocker);
// - a named, unpaired audio device that shows up is offered in a sheet
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

    readonly property bool offering: prefs.offerNew && prefs.offerPopup
    readonly property var adapter: BluetoothService.adapter
    readonly property bool btOn: BluetoothService.enabled
    readonly property bool asleep: SessionService.locked || IdleService.isShellLocked || IdleService.monitorsOff
    readonly property bool fullscreen: ToplevelManager.activeToplevel?.fullscreen ?? false

    // Why the last background scan was skipped ("" when it ran), shown by the newDeviceStatus IPC call
    property string lastSkip: ""

    // --- Background scan ---------------------------------------------------------
    property bool _owns: false
    // Orbit views that are scanning: a background scan must not stop theirs
    property int _viewScans: 0

    function holdScan(on) {
        _viewScans = Math.max(0, _viewScans + (on ? 1 : -1));
        // A view took over: its own timer decides when discovery ends
        if (on)
            _owns = false;
    }

    function _audioConnected() {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].connected && Catalog.families[Catalog.resolve(list[i], ({}))] === "audio")
                return true;
        return false;
    }

    function scanOnce() {
        const display = UPower.displayDevice;
        const hasBattery = !!display && display.isLaptopBattery;
        lastSkip = Offer.scanBlocker({
            "enabled": offering && prefs.offerScan,
            "btOn": btOn && !!adapter,
            "asleep": asleep,
            "busy": !!adapter && adapter.discovering,
            "audioConnected": _audioConnected(),
            "onBattery": UPower.onBattery,
            "level": hasBattery ? Math.round(display.percentage * 100) : -1,
            "minLevel": prefs.offerMinBattery
        });
        if (lastSkip)
            return;
        adapter.discovering = true;
        _owns = true;
        scanStop.restart();
    }

    function _stopOwnScan() {
        scanStop.stop();
        if (_owns && _viewScans === 0 && adapter && adapter.discovering)
            adapter.discovering = false;
        _owns = false;
    }

    Timer {
        id: scanCycle
        interval: Math.max(30, prefs.offerEvery) * 1000
        repeat: true
        running: root.offering && root.prefs.offerScan && root.btOn && !root.asleep
        onTriggered: root.scanOnce()
    }

    // Long enough for a headset in pairing mode to answer an inquiry
    Timer {
        id: scanStop
        interval: 8000
        onTriggered: root._stopOwnScan()
    }

    onOfferingChanged: if (!offering)
        _stopOwnScan()
    onAsleepChanged: {
        if (asleep)
            _stopOwnScan();
        else
            _showNext();
    }
    onFullscreenChanged: if (!fullscreen)
        _showNext()

    // --- Detection ---------------------------------------------------------------
    // address -> epoch ms before which it is not offered again
    property var _snoozed: ({})
    property var _queue: []
    // Devices BlueZ already lists when the shell starts are its cache, not
    // news: they wait out one snooze before they can be offered
    property bool _primed: false

    function deviceFor(address) {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].address === address)
                return list[i];
        return null;
    }

    function _family(d) {
        return Catalog.families[Catalog.resolve(d, ({}))] || "";
    }

    function _isCandidate(d) {
        return !!d && Offer.isCandidate({
            "address": d.address,
            "name": Catalog.deviceName(d),
            "paired": d.paired || d.bonded,
            "connected": d.connected
        }, Guard.offerFamily(d.icon), prefs.ignoredDevices);
    }

    function _snooze(address) {
        const next = Object.assign({}, _snoozed);
        next[address] = Date.now() + Offer.snoozeMs;
        _snoozed = next;
    }

    function consider(address) {
        if (!offering)
            return;
        if (!_primed) {
            _snooze(address);
            return;
        }
        // Only what discovery just found is in range (Quickshell has no RSSI)
        if (!adapter || !adapter.discovering)
            return;
        if (current === address || _queue.indexOf(address) >= 0)
            return;
        if (!Offer.offerable(address, _snoozed, Date.now()))
            return;
        _queue = _queue.concat([address]);
        _showNext();
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: root._primed = true
    }

    Instantiator {
        model: Bluetooth.devices

        delegate: QtObject {
            required property var modelData
            // The name often arrives a moment after the device itself
            readonly property bool candidate: root.offering && root._isCandidate(modelData)
            onCandidateChanged: if (candidate)
                root.consider(modelData.address)
            Component.onCompleted: if (candidate)
                root.consider(modelData.address)
        }
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
    readonly property var ancInfo: anc && current && !_demo ? (anc.states[current] || null) : null
    readonly property var device: _demo ? demoDevice : current ? deviceFor(current) : null
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
    readonly property QtObject demoDevice: QtObject {
        property string address: "demo"
        property string name: "WH-1000XM6"
        property string deviceName: "WH-1000XM6"
        property string icon: "audio-headphones"
        property bool paired: false
        property bool bonded: false
        property bool connected: false
        property bool pairing: false
        property bool batteryAvailable: connected
        property real battery: 0.8
        function disconnect() {
            connected = false;
        }
        function cancelPair() {}
    }

    function demo() {
        if (current)
            return "A pop-up is already shown";
        _demo = true;
        demoDevice.paired = false;
        demoDevice.connected = false;
        const top = ToplevelManager.activeToplevel;
        _screen = top && top.screens && top.screens.length ? top.screens[0] : Quickshell.screens[0];
        phase = "offer";
        pendingName = "";
        current = "demo";
        showDelay.restart();
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
        while (_queue.length) {
            const address = _queue[0];
            _queue = _queue.slice(1);
            if (!_isCandidate(deviceFor(address)))
                continue;
            // On the screen being looked at: the one of the active window
            const top = ToplevelManager.activeToplevel;
            _screen = top && top.screens && top.screens.length ? top.screens[0] : Quickshell.screens[0];
            phase = "offer";
            pendingName = "";
            current = address;
            // Mapped first, then shown: the entrance animates from the bar
            showDelay.restart();
            return;
        }
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
            _snooze(current);
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
                // No device name in the journal: it may be a person's name
                console.warn("orbitBluetooth: pairing failed: " + root.lastError);
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
        function onPairedChanged() {}
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

    Component.onDestruction: _stopOwnScan()

    ProfileCheck {
        id: profileCheck
    }
}
