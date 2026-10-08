import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "components/common"
import "components/noise"
import "components/volume"

// Test of the hard cases for empty values (NAK-60): a headset that
// disconnects mid-play and leaves the list, an output that vanishes or has
// no name, a UPower battery that disappears, a helper that dies during a
// command. Each step plays one case against the real components; the QML
// warnings and TypeErrors they print are counted by tests/qml/run.sh, which
// fails this test when there is any (a guard exists only where this showed
// one). One step every 100 ms. Run with tests/qml/run.sh.
Item {
    id: h

    readonly property string a: "02:00:00:00:10:06"
    readonly property string b: "02:00:00:00:10:07"

    Component {
        id: dev
        Device {}
    }
    Component {
        id: upDevice
        QtObject {
            property string nativePath: ""
            property bool isLaptopBattery: false
            property int state: 1
            property real percentage: 0.5
            property real timeToFull: 0
            property real timeToEmpty: 3600
            property real changeRate: -2
            property bool healthSupported: true
            property real healthPercentage: 90
        }
    }
    Component {
        id: nodeType
        QtObject {
            property string name: ""
        }
    }

    function make(address, name, connected) {
        return dev.createObject(h, {
            "address": address,
            "name": name,
            "deviceName": name,
            "icon": "audio-headset",
            "paired": true,
            "connected": connected
        });
    }
    function setDevices(list) {
        Bluetooth.list = Bluetooth.devices = list;
    }

    property var published: ({})
    DeviceLog {
        id: log
        publish: (name, value) => h.published[name] = value
    }

    AncService {
        id: svc
        chatOffOnDisconnect: true
    }

    ScopeFeed {
        id: feed
        active: true
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    property var headset: null
    property var other: null
    property var up: null

    property var steps: [() => {
            // A headset connects and plays, with a battery level
            h.headset = h.make(h.a, "WH-1000XM6", true);
            h.setDevices([h.headset]);
        }, () => {
            check("the connection is recorded", [typeof log.since[h.a], (log.batteryLog[h.a] || []).length], ["number", 1]);
            h.headset.battery = 0.7;
        }, () => {
            check("a battery change is recorded", log.batteryLog[h.a].length, 2);
            // It disconnects in mid-play, then BlueZ drops it from the list
            h.headset.connected = false;
        }, () => {
            check("a disconnection forgets the connection", [log.since[h.a], log.batteryLog[h.a]], [undefined, undefined]);
            // BlueZ destroys the object while the list still holds it
            h.headset.destroy();
        }, () => {
            h.setDevices([]);
        }, () => {
            // A battery report for a device removed during the same event
            h.other = h.make(h.b, "WF-1000XM5", true);
            h.setDevices([h.other]);
        }, () => {
            h.other.battery = 0.4;
            h.other.destroy();
        }, () => {
            h.setDevices([]);
        }, () => {
            // UPower: a Bluetooth peripheral's battery shows up, then vanishes
            h.up = upDevice.createObject(h, {
                "nativePath": "/org/bluez/hci0/dev_" + h.b.replace(/:/g, "_")
            });
            UPower.devices = [h.up];
        }, () => {
            check("UPower facts are recorded", log.power[h.b]?.percentage, 50);
            h.up.destroy();
        }, () => {
            UPower.devices = [];
        }, () => {
            check("and forgotten when the battery vanishes", log.power[h.b], undefined);
            // Its default output vanishes, comes back, or has no name
            feed.node = nodeType.createObject(h, {
                "name": "bluez_output.x.1"
            });
        }, () => {
            check("an output with a name feeds cava", feed._conf !== "", true);
            feed.node.destroy();
        }, () => {
            feed.node = null;
        }, () => {
            check("no output: no cava", feed._conf, "");
            feed.node = nodeType.createObject(h, {});
        }, () => {
            check("an output with an empty name still starts a feed", feed._conf !== "", true);
            feed.node = null;
        }, () => {
            // The helper dies while a command is waiting, and the headset is gone
            h.headset = h.make(h.a, "WH-1000XM6", true);
            h.setDevices([h.headset]);
        }, () => {
            check("a command opens a session", svc.send(h.a, "mode", "nc"), true);
            h.headset.connected = false;
            h.setDevices([]);
        }, () => {
            const proc = svc._sessions[h.a];
            if (proc)
                proc.exited(1);
            check("the dead helper leaves no session", svc._sessions[h.a] ?? null, null);
            check("a command for a headset that left is refused", svc.send(h.a, "mode", "ambient"), false);
            svc.disconnectDevice(h.a);
        }, () => {
            // The shell stops while one helper is open and another has died
            h.headset = h.make(h.b, "WH-1000XM6", true);
            h.setDevices([h.headset]);
        }, () => {
            svc.send(h.b, "mode", "nc");
            svc._sessions[h.b].exited(1);
            svc.send(h.b, "mode", "off");
            svc.destroy();
        }, () => {
            check("no helper outlives the service", ProcessLog.live.filter(p => p.address !== undefined).length, 0);
        }]
    property int i: 0
    // A step that throws is a failure, not a test that never ends
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            try {
                h.steps[h.i++]();
            } catch (e) {
                h.failures++;
                print("FAIL step " + h.i + " threw: " + e);
            }
            if (h.i >= h.steps.length) {
                print(h.failures ? h.failures + " failure(s)" : "all passed");
                Qt.exit(h.failures ? 1 : 0);
            }
        }
    }
}
