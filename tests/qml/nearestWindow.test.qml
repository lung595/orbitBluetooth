import QtQuick
import Quickshell.Bluetooth
import qs.Services
import "components/pairing"

// The nearest-PC filter in the "new device" pop-up flow (NAK-110): the signal
// is read when a candidate appears, a far PC waits, the signal is read again
// when the wait ends, and no reading keeps today's behavior. The signal comes
// from the fake device's `rssi`; the busctl side is tests/signal.test.js.
// Run with tests/qml/run.sh.
Item {
    id: h
    QtObject {
        id: prefs
        property bool offerNew: true
        property bool offerPopup: true
        property bool offerScan: false
        property int offerEvery: 60
        property int offerMinBattery: 30
        property bool realPictures: false
        property bool reduceMotion: false
        property var ignoredDevices: ({})
        function setIgnored(a, n, on) {
        }
    }
    Component {
        id: dev
        Device {}
    }
    NewDeviceWatch {
        id: w
        prefs: prefs
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function add(addr, name, rssi) {
        const d = dev.createObject(h, {
            "address": addr,
            "name": name,
            "deviceName": name,
            "icon": "audio-headphones",
            "rssi": rssi
        });
        const a = Bluetooth.list.slice();
        a.push(d);
        Bluetooth.list = a;
        Bluetooth.devices = a;
        return d;
    }
    function remove(addr) {
        const a = Bluetooth.list.filter(d => d.address !== addr);
        Bluetooth.list = a;
        Bluetooth.devices = a;
    }
    // Close the sheet and take the device off the list: re-assigning the fake
    // list rebuilds the delegates, which would consider it all over again
    function dismiss() {
        remove(w.current);
        w.close();
    }
    // Same for devices that never got a window
    function drop(addr) {
        remove(addr);
    }
    property var strong: null
    property var weak: null

    // One step every 600 ms. Floor -75, near -45, longest wait 1500 ms, so
    // -63 waits 900 ms; a screen that is off adds 600 ms
    property var steps: [() => {
            w.offers.nearestOptions = {
                "maxDelayMs": 1500,
                "tieMs": 600
            };
            BluetoothService.adapter.discovering = true;
            add("00:00:00:00:00:11", "Strong 1", -40);
        }, () => {
            check("strong signal: opens at once", w.current, "00:00:00:00:00:11");
            dismiss();
        }, () => {}, () => {
            check("closed", w.current, "");
            add("00:00:00:00:00:12", "Below floor", -90);
        }, () => {
            check("below the floor: no window", [w.current, w.offers.pending, w.offers._waiting], ["", [], []]);
            drop("00:00:00:00:00:12");
            add("00:00:00:00:00:13", "Weak 1", -63);
        }, () => {
            // 900 ms wait, 600 ms into it
            check("weak signal: waits first", [w.current, w.offers._waiting], ["", ["00:00:00:00:00:13"]]);
        }, () => {
            check("weak signal: opens after the wait", w.current, "00:00:00:00:00:13");
            check("nothing left waiting", w.offers._waiting, []);
            dismiss();
        }, () => {}, () => {
            check("closed", w.current, "");
            h.weak = add("00:00:00:00:00:14", "Weak 2", -63);
        }, () => {
            // The headset connected to another PC: its signal is gone at the end of the wait
            h.weak.rssi = undefined;
        }, () => {}, () => {
            check("signal gone at the end of the wait: no window", [w.current, w.offers.pending, w.offers._waiting], ["", [], []]);
            drop("00:00:00:00:00:14");
            h.weak = add("00:00:00:00:00:15", "Weak 3", -63);
        }, () => {
            // It drifted away during the wait
            h.weak.rssi = -85;
        }, () => {}, () => {
            check("fell below the floor during the wait: no window", [w.current, w.offers._waiting], ["", []]);
            drop("00:00:00:00:00:15");
            h.weak = add("00:00:00:00:00:16", "Weak 4", -63);
        }, () => {
            // Paired from elsewhere (e.g. Orbit's own link) during the wait: no longer a candidate
            h.weak.paired = true;
        }, () => {}, () => {
            check("no longer a candidate at the end of the wait: no window", [w.current, w.offers._waiting], ["", []]);
            drop("00:00:00:00:00:16");
            h.weak = add("00:00:00:00:00:17", "Weak 5", -63);
        }, () => {
            // Discovery ends during the wait: BlueZ clears every signal, which proves nothing
            h.weak.rssi = undefined;
            BluetoothService.adapter.discovering = false;
        }, () => {}, () => {
            check("signal missing after discovery ended: today's behavior", w.current, "00:00:00:00:00:17");
            dismiss();
        }, () => {}, () => {
            BluetoothService.adapter.discovering = true;
            add("00:00:00:00:00:18", "No reading", undefined);
        }, () => {
            check("no measurement: today's behavior, at once", w.current, "00:00:00:00:00:18");
            dismiss();
        }, () => {}, () => {
            // A screen that is off waits longer: -63 -> 900 ms + 600 ms
            SessionService.locked = false;
            IdleService.monitorsOff = true;
            add("00:00:00:00:00:19", "Weak 6", -63);
        }, () => {
            IdleService.monitorsOff = false;
            check("screen off: the wait is longer (still waiting)", [w.current, w.offers._waiting], ["", ["00:00:00:00:00:19"]]);
        }, () => {
            check("still waiting past the plain 900 ms", w.current, "");
        }, () => {
            check("then opens", w.current, "00:00:00:00:00:19");
            dismiss();
        }, () => {}, () => {
            // One read when a device appears, one more when a wait ends
            // (none for a device that stopped being a candidate), none at rest
            const reads = w.offers.children.filter(c => c.log !== undefined)[0].log;
            check("reads: first and second readings only", reads.length, 14);
        }, () => {
            print(h.failures ? h.failures + " failures" : "all passed");
            Qt.exit(h.failures ? 1 : 0);
        }]
    property int i: 0
    Timer {
        interval: 600
        repeat: true
        running: true
        // New devices only count once the start-up cache is primed
        onTriggered: {
            if (h.i === 0 && !w.offers._primed)
                return;
            h.steps[h.i++]();
        }
    }
}
