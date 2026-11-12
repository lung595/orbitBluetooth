import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "components/volume"

// Test of RouteDevice's absolute-volume probe (audit 2026-11): every new
// connection gets its own look and its own retry, and a busctl answer that
// comes after the sound output went is dropped, so it cannot stand in for
// the next connection's. The sink is the mock Pipewire's extraSinks, busctl
// the stand-in of Quickshell.Io. Made-up address only. Run with
// tests/qml/run.sh.
Item {
    id: h

    readonly property string mac: "AA:BB:CC:DD:EE:31"
    Component {
        id: fakeNode
        QtObject {
            required property string name
            property bool isSink: true
            property bool isStream: false
            readonly property bool ready: true
            readonly property QtObject audio: QtObject {
                property real volume: 1
                property bool muted: false
            }
        }
    }
    readonly property QtObject deviceSink: fakeNode.createObject(h, {
        "name": "bluez_output.AA_BB_CC_DD_EE_31.1"
    })

    RouteDevice {
        id: dev
        device: ({
                "address": h.mac,
                "deviceName": "Buds",
                "connected": true,
                "dbusPath": "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_31"
            })
    }

    // The `busctl tree` of the probe, null when none was started
    function tree() {
        return ProcessLog.live.find(p => p.command[1] === "tree") || null;
    }
    // BlueZ lists no transport: the device follows this PC's level
    function noTransport() {
        const p = tree();
        p.stdout.text = "";
        p.running = false;
        p.exited(0);
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    property double holdUntil: 0
    function wait(ms) {
        holdUntil = Date.now() + ms;
    }
    readonly property var steps: [
        () => {
            Pipewire.extraSinks = [deviceSink];
            check("the sound output shows up: the probe runs", !!tree() && tree().running, true);
            noTransport();
            check("no transport: the device follows this PC", dev.absolute, 0);
            // Gone before the retry: the next connection starts afresh
            Pipewire.extraSinks = [];
            check("disconnected: unknown again", dev.absolute, -1);
            // Long enough for the first connection's retry to have passed
            wait(4300);
        },
        () => {
            Pipewire.extraSinks = [deviceSink];
            check("connected again: a new probe", tree().running, true);
            noTransport();
            wait(4300);
        },
        () => {
            check("the second connection gets its retry too", tree().running, true);
            // Gone while the probe runs: its late answer is dropped
            Pipewire.extraSinks = [];
            noTransport();
            check("a late answer leaves it unknown", dev.absolute, -1);
        },
        () => {
            Pipewire.extraSinks = [deviceSink];
            check("so the next connection probes again", tree().running, true);
            noTransport();
            Pipewire.extraSinks = [];
        }
    ]
    property int next: 0
    Timer {
        // 1 ms: a 0 ms timer never fires under the offscreen test platform
        interval: 1
        repeat: true
        running: true
        onTriggered: {
            if (Date.now() < h.holdUntil)
                return;
            if (h.next >= h.steps.length) {
                stop();
                print(h.failures ? h.failures + " failure(s)" : "all passed");
                Qt.exit(h.failures ? 1 : 0);
                return;
            }
            h.steps[h.next++]();
        }
    }
}
