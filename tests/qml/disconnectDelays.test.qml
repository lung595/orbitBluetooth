import QtQuick
import Quickshell.Bluetooth
import qs.Services
import "components/delay"

// Test of DisconnectDelays: a delay is one single-shot timer and nothing at
// rest; it ends by disconnecting the device, is dropped when the device leaves
// by itself, can be cancelled or replaced, and the Sands flag follows the
// plugin list. The wait is shortened by writing an end time a few
// milliseconds away. Run with tests/qml/run.sh.
Item {
    id: h

    property int failures: 0
    property var published: []
    function check(what, got, expected) {
        if (JSON.stringify(got) === JSON.stringify(expected))
            return;
        failures++;
        print("FAIL " + what + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(got));
    }

    Device {
        id: xm6
        address: "AA:BB:CC:DD:EE:01"
        name: "WH-1000XM6"
        connected: true
    }
    Device {
        id: pods
        address: "AA:BB:CC:DD:EE:02"
        name: "Pods Demo"
        connected: true
    }
    Device {
        id: off
        address: "AA:BB:CC:DD:EE:03"
        name: "Speaker Off"
        connected: false
    }
    Device {
        id: pods2
        address: "AA:BB:CC:DD:EE:04"
        name: "Pods Two"
        connected: true
    }
    DisconnectDelays {
        id: engine
        publish: value => h.published.push(value)
    }

    function last() {
        return h.published[h.published.length - 1];
    }
    // A delay that ends in a few milliseconds
    function soon(address) {
        engine._set(Object.assign({}, engine.pending, {
            [address]: Date.now() + 30
        }));
    }

    property var steps: [
        {
            "wait": 20,
            "run": () => {
                Bluetooth.list = Bluetooth.devices = [xm6, pods, pods2, off];
                check("published at start, nothing pending", [last().ends, last().sands], [
                    {},
                    false]);
                check("nothing pending, nothing runs", engine.pending, {});
                check("a bad delay", engine.start("xm6", "0").why, "badDelay");
                check("an unknown device", engine.start("zzz", "5").why, "none");
                check("a device that is not connected is not a target", engine.start("speaker", "5").why, "none");
                check("an ambiguous name", engine.start("pods", "5").why, "ambiguous");
                check("a unique fragment is fine", engine.start("demo", "5").ok, true);
                engine.stop("demo");
                const r = engine.start("aa:bb:cc:dd:ee:01", "5");
                check("an address works", [r.ok, r.address, r.minutes], [true, xm6.address, 5]);
                check("the end time is published", Math.abs(last().ends[xm6.address] - Date.now() - 300000) < 2000, true);
                check("another start replaces it", [engine.start("xm6", "10").ok, Math.abs(engine.pending[xm6.address] - Date.now() - 600000) < 2000], [true, true]);
                check("cancel", [engine.stop("xm6").ok, engine.pending], [true,
                    {}
                ]);
                check("cancel of nothing says so", engine.stop("xm6").why, "nothing");
                check("the cancel is published", last().ends, {});
                PluginService.availablePlugins = {
                    "smartTimer": {}
                };
            }
        },
        {
            "wait": 150,
            "run": () => {
                check("Sands appearing is published", last().sands, true);
                engine.start("xm6", "5");
                h.soon(xm6.address);
            }
        },
        {
            "wait": 20,
            "run": () => {
                check("the end disconnects the device", [xm6.disconnects, xm6.connected], [1, false]);
                check("and the delay is gone", engine.pending, {});
                engine.start("demo", "5");
                pods.connected = true;
            }
        },
        {
            "wait": 150,
            "run": () => {
                pods.connected = false;
                check("a device that leaves by itself drops its delay", [engine.pending, last().ends], [
                    {},
                    {}
                ]);
                pods.connected = true;
                engine.start("demo", "5");
                h.soon(pods.address);
                pods.connected = false;
            }
        },
        {
            "wait": 20,
            "run": () => {
                check("and nothing is disconnected twice", pods.disconnects, 0);
                PluginService.availablePlugins = {};
            }
        },
        {
            "wait": 20,
            "run": () => {
                check("Sands leaving is published", last().sands, false);
            }
        }
    ]
    property int at: 0

    Timer {
        id: clock
        onTriggered: h.next()
    }
    function next() {
        if (at >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        const step = steps[at++];
        step.run();
        clock.interval = step.wait;
        clock.start();
    }
    Component.onCompleted: Qt.callLater(next)
}
