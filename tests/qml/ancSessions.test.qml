import QtQuick
import Quickshell.Bluetooth
import "components/noise"

// Test of AncService's sessions with the wearing sensor (D277): which
// headsets get a control session and when it closes, that a helper which
// cannot start never loops, that an Orbit-initiated disconnect is not
// reopened, and that the option and Noise control switch it off cleanly.
// Nothing here talks to a headset: the Process stand-in records what is
// written and the test plays the helper's lines. One step every 100 ms.
// Run with tests/qml/run.sh.
Item {
    id: h

    readonly property string a: "00:00:00:00:0A:01"
    readonly property string b: "00:00:00:00:0B:02"
    readonly property string c: "00:00:00:00:0C:03"
    readonly property string d: "00:00:00:00:0D:04"

    Component {
        id: dev
        Device {}
    }

    // A has a wearing sensor, B has not, C is another brand, D is not connected
    property var headsets: ({})
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

    // Chat-off on disconnect is off here: the wearing sensor alone is
    // what opens a session, until the steps that test the two together
    AncService {
        id: svc
        chatOffOnDisconnect: false
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    function session(address) {
        return svc._sessions[address] || null;
    }
    // The helper says something on its standard output
    function say(address, report) {
        session(address).stdout.read(JSON.stringify(report));
    }
    function ready(wear, chat) {
        return {
            "status": "ready",
            "model": "Test headset",
            "features": {
                "modes": ["nc", "ambient", "off"],
                "chat": !!chat,
                "wear": wear
            },
            "state": {
                "mode": "nc",
                "chat": !!chat,
                "wearing": wear ? 0 : null
            }
        };
    }
    // The helper ends: a closed standard input, a crash, a headset that left
    function end(address, code) {
        session(address).exited(code);
    }
    function timer(interval) {
        return svc.resources.find(o => o.interval === interval);
    }
    // The 2.5 s wait after a reconnection and the 4 s wait for "chat off"
    function settle() {
        timer(2500).triggered();
    }

    property var old: null
    property var steps: [() => {
            h.headsets = {
                "a": make(h.a, "WH-1000XM6", true),
                "b": make(h.b, "WF-1000XM5", true),
                "c": make(h.c, "Bose QuietComfort 45", true),
                "d": make(h.d, "WH-1000XM4", false)
            };
            Bluetooth.list = Bluetooth.devices = Object.values(h.headsets);
        }, () => {
            check("option off: no session at rest", [h.session(h.a), h.session(h.b)], [null, null]);
            svc.watch(h.a, true);
            check("a view opens one", h.session(h.a) !== null, true);
            svc.watch(h.a, false);
            check("the view leaves, the session closes", h.session(h.a).stdinEnabled, false);
            h.end(h.a, 0);
            check("and does not come back", h.session(h.a), null);
            svc.wearPause = true;
        }, () => {
            const s = h.session(h.a);
            check("option on: a Sony headset gets a session", s !== null, true);
            check("it is asked for the wearing sensor", s.written, ["set wear on\n"]);
            check("the device name goes through the environment", [s.command.indexOf("WH-1000XM6"), s.environment.ORBIT_ANC_NAME], [-1, "WH-1000XM6"]);
            check("the first, unknown, headset is probed too", h.session(h.b) !== null, true);
            check("another brand gets none", h.session(h.c), null);
            check("a headset that is not connected gets none", h.session(h.d), null);
            h.say(h.a, h.ready(true));
            h.say(h.b, h.ready(false));
            check("with a sensor: the session stays", h.session(h.a).stdinEnabled, true);
            check("without a sensor: it closes at once", h.session(h.b).stdinEnabled, false);
            check("the wearing status is published", svc.snapshots[h.a].state.wearing, 0);
        }, () => {
            h.end(h.b, 0);
            check("no sensor: no reopening, no loop", h.session(h.b), null);
            h.old = h.session(h.a);
            h.end(h.a, 1);
            check("a session that was ready and dropped comes back", [h.session(h.a) !== null, h.session(h.a) !== h.old], [true, true]);
            h.say(h.a, {
                "status": "error",
                "error": "refused"
            });
            check("an error closes it", h.session(h.a).stdinEnabled, false);
            h.end(h.a, 1);
            check("and nothing retries until a reconnection", h.session(h.a), null);
        }, () => {
            h.headsets.a.connected = false;
            check("a disconnection forgets the state", svc.snapshots[h.a], undefined);
            svc.chatOffOnDisconnect = true;
            h.headsets.a.connected = true;
            check("a fresh link is left to settle", h.session(h.a), null);
            h.settle();
            const s = h.session(h.a);
            check("then one session opens, wear first", s.written, ["set wear on\n", "set chat off\n"]);
            h.end(h.a, 1);
            check("a helper that never got ready does not loop", h.session(h.a), null);
        }, () => {
            svc.watch(h.a, true);
            h.say(h.a, h.ready(true, true));
            svc.watch(h.a, false);
            check("the viewer leaves, the wearing keeps the session", h.session(h.a).stdinEnabled, true);
            svc.disconnectDevice(h.a);
            const s = h.session(h.a);
            check("disconnecting from Orbit turns chat off first", s.written.slice(-1), ["set chat off\n"]);
            check("and lets the session close", s.stdinEnabled, false);
            check("the headset is still connected", h.headsets.a.connected, true);
            // BlueZ takes a moment to say it is gone: the link must not be reopened meanwhile
            h.headsets.a.lingers = true;
            h.end(h.a, 0);
            check("once confirmed it disconnects", h.headsets.a.disconnects, 1);
            check("and the session is not reopened", [h.session(h.a), svc._leaving], [null,
                {}
            ]);
            h.headsets.a.connected = false;
        }, () => {
            svc.chatOffOnDisconnect = false;
            h.headsets.a.connected = true;
            h.settle();
            h.say(h.a, h.ready(true));
            svc.wearPause = false;
            check("option off: the headset is told to stop reporting", h.session(h.a).written.slice(-1), ["set wear off\n"]);
            check("and the session closes", h.session(h.a).stdinEnabled, false);
            h.end(h.a, 0);
            check("nothing comes back", h.session(h.a), null);
            svc.wearPause = true;
            check("option on again: it opens again", h.session(h.a) !== null, true);
            h.say(h.a, h.ready(true));
            svc.active = false;
            check("Noise control off: the wearing session closes too", h.session(h.a).stdinEnabled, false);
            h.end(h.a, 0);
            check("and none is left", [h.session(h.a), h.session(h.b)], [null, null]);
            svc.active = true;
        }, () => {
            h.say(h.a, h.ready(true));
            h.headsets.a.connected = false;
            h.say(h.a, {
                "status": "error",
                "error": "link lost"
            });
            check("a late line after the disconnection leaves no state behind", svc.snapshots[h.a], undefined);
            h.end(h.a, 1);
            h.headsets.a.connected = true;
            h.settle();
            check("and the headset gets its session back when it returns", h.session(h.a) !== null, true);
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
