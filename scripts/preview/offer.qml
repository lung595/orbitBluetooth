import QtQuick
import Quickshell.Bluetooth
import "../../components/pairing"

// Bench scene for the "new device" queue (OfferQueue), no window drawn:
// made-up headsets keep showing up during a discovery and the pop-up takes
// them, so banc-ab.sh can compare what the queue costs from one commit to the
// next. Run from scripts/preview with the test stubs (Quickshell.Bluetooth)
// and the signal reader swapped for tests/qml/SignalRead.qml:
//   qml-qt6 -I imports -I ../../tests/qml/stubs offer.qml -- <mode>
// Modes: idle (discovery on, nobody new), weak (4 new headsets a second, far
// enough to wait: two reads and a timer each), none (same, no signal
// reading: today's path).
Item {
    id: scene

    readonly property string mode: Qt.application.arguments.indexOf("weak") >= 0 ? "weak" : Qt.application.arguments.indexOf("none") >= 0 ? "none" : "idle"
    property int serial: 0
    property var batch: []

    QtObject {
        id: prefs
        property var ignoredDevices: ({})
    }

    QtObject {
        id: adapter
        property bool discovering: true
    }

    Component {
        id: device

        QtObject {
            property string address
            property string name
            property string deviceName: name
            property string icon: "audio-headset"
            property string dbusPath: "/org/bluez/hci0/dev_" + address.replace(/:/g, "_")
            property bool paired: false
            property bool bonded: false
            property bool connected: false
            property var rssi: undefined
        }
    }

    OfferQueue {
        id: queue
        prefs: prefs
        offering: true
        adapter: adapter
        // The pop-up shows each one as soon as it is queued
        onQueued: {
            while (take() !== "") {}
        }
    }

    function hex(n) {
        return ("0" + (n & 255).toString(16).toUpperCase()).slice(-2);
    }

    // 4 new headsets a second (fresh addresses, so no snooze ever hides them);
    // each stays 7 s, past the longest wait, then goes: the list stays at 28
    function churn() {
        const next = batch.slice();
        for (let i = 0; i < 4; i++) {
            serial++;
            next.push(device.createObject(scene, {
                "address": "AA:BB:CC:" + hex(serial >> 16) + ":" + hex(serial >> 8) + ":" + hex(serial),
                "name": "Bench Headset " + serial,
                "rssi": mode === "weak" ? -70 : undefined
            }));
        }
        const old = next.splice(0, Math.max(0, next.length - 28));
        batch = next;
        Bluetooth.list = next;
        Bluetooth.devices = next;
        old.forEach(d => d.destroy());
    }

    Timer {
        // After the queue's 4 s priming: what shows up before is BlueZ's cache
        interval: 1000
        repeat: true
        running: scene.mode !== "idle"
        onTriggered: scene.churn()
    }
}
