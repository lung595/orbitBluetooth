import QtQuick
import qs.Services
import "../device/DeviceCatalog.js" as Catalog

// The pairing steps of the "new device" pop-up for one device: pair, check
// it cannot also type (ProfileCheck, P115), trust and connect, with the
// time-out and the demo's scripted version. It only moves `phase`; what the
// pop-up shows for each phase is NewDeviceWatch's and the sheet's business.
Item {
    id: flow

    // The address of the device the pop-up shows ("" when none)
    required property string current
    required property var device
    required property bool demo
    // The made-up headset the demo moves on by itself
    required property QtObject demoDevice

    // "offer", "pairing", "confirm", "connecting", "done" or "failed"
    property string phase: "offer"
    // Why the last pairing failed (newDeviceStatus), "" otherwise
    property string lastError: ""

    // The device is connected and, unless the check still has to run, trusted
    signal arrived

    // Connected after the check: Bluetooth LE lists its profiles only once
    // connected, so look once more (it may still turn out to type)
    property bool _checked: false

    function reset() {
        phase = "offer";
    }

    // Same path as dragging a device into the orbit (OrbitScene.startConnect)
    function connect() {
        const d = device;
        if (!d)
            return;
        const address = current;
        lastError = "";
        timeout.restart();
        _checked = false;
        if (demo) {
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
            if (flow.current !== address || (flow.phase !== "pairing" && flow.phase !== "connecting"))
                return;
            if (res && res.error) {
                flow.lastError = String(res.error);
                // A fixed line: the error text may carry a device name or address (value 11)
                console.warn("orbitBluetooth: pairing failed while " + flow.phase);
                flow.phase = "failed";
                timeout.stop();
                return;
            }
            flow._checkThenConnect(d, address);
        });
    }

    // Trust only after checking it cannot also type (P115). The device stays
    // in "pairing" until ProfileCheck has run: it then moves to "connecting"
    function _checkThenConnect(d, address) {
        profileCheck.check(d, Catalog.families[Catalog.resolve(d, ({}))] || "", verdict => {
            if (flow.current !== address)
                return;
            if (verdict === "input") {
                // Blocked by ProfileCheck until the user answers in the sheet
                flow.phase = "confirm";
                timeout.stop();
            } else if (verdict === "refused") {
                flow.lastError = "could not check";
                flow.phase = "failed";
                timeout.stop();
            } else if (flow.phase === "pairing" || flow.phase === "confirm") {
                flow.phase = "connecting";
                if (d.connected)
                    flow._connected();
                else
                    BluetoothService.connectDeviceWithTrust(d);
            } else if (flow.phase === "done") {
                flow._checked = true;
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
        timeout.restart();
        BluetoothService.connectDeviceWithTrust(d);
    }

    // Leaving the question unanswered means no: the device is forgotten
    function dropUnconfirmed() {
        if (phase === "confirm" && device && !demo)
            profileCheck.deny(device);
    }

    // The sheet is closing: forget an unanswered question, stop waiting
    function release() {
        dropUnconfirmed();
        timeout.stop();
    }

    // The user gave up: stop the demo and let go of the device
    function abort() {
        demoStep.stop();
        dropUnconfirmed();
        const d = device;
        if (d) {
            if (d.pairing)
                d.cancelPair();
            d.disconnect();
        }
    }

    function _connected() {
        phase = "done";
        timeout.stop();
        if (!_checked && !demo)
            _checkThenConnect(device, current);
        arrived();
    }

    Connections {
        target: flow.device
        function onConnectedChanged() {
            if (flow.device.connected && flow.phase === "connecting")
                flow._connected();
        }
    }

    // Pairing waits for the user in DMS's pairing dialog: be patient
    Timer {
        id: timeout
        interval: 45000
        onTriggered: if (flow.phase === "pairing" || flow.phase === "connecting") {
            flow.lastError = "timed out in " + flow.phase;
            flow.phase = "failed";
        }
    }

    Timer {
        id: demoStep
        interval: 1100
        onTriggered: {
            if (flow.phase === "pairing") {
                // The demo has no real device to check: it moves on itself
                flow.demoDevice.paired = true;
                flow.phase = "connecting";
                restart();
            } else if (flow.phase === "connecting") {
                flow.demoDevice.connected = true;
            }
        }
    }

    ProfileCheck {
        id: profileCheck
    }
}
