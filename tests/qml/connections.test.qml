import QtQuick
import qs.Services
import "components/scene"

// Test of OrbitConnections' keyboard-profile question (P115): a "headset"
// that can also type is held back with a toast and no other note; dragging
// it in again within the minute unblocks and connects it; letting the minute
// pass forgets it. One step every 300 ms. Run with tests/qml/run.sh.
Item {
    id: h

    Component {
        id: dev
        Device {}
    }

    // The scene, reduced to what the connection flow calls
    QtObject {
        id: scene
        property var notes: []
        property var played: []
        readonly property var ancService: null
        readonly property var sounds: ({
                "play": name => scene.played = scene.played.concat([name])
            })
        function wake() {
        }
        function explain(text) {
            notes = notes.concat([text]);
        }
        function emitWave(on) {
        }
    }

    // One planet, its device swapped in by each step
    Repeater {
        id: bodies
        model: 1
        delegate: Item {
            property var device: null
            readonly property string address: device ? device.address : ""
            readonly property bool connected: device ? device.connected : false
            property string phase: "idle"
            property real cancelledAt: 0
            property int shakes: 0
            function shake() {
                shakes++;
            }
            function release() {
            }
            function celebrate() {
            }
        }
    }

    OrbitConnections {
        id: connections
        scene: scene
        bodies: bodies
    }

    // The one-minute wait is private to the flow: the test finds it to
    // check it runs and to end it early instead of waiting 60 s
    function confirmWait() {
        return connections.resources.find(o => o.interval === 60000);
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // A new headset that also exposes the classic keyboard profile
    function typingHeadset(name) {
        const b = bodies.itemAt(0);
        b.device = dev.createObject(h, {
            "address": "00:00:00:00:00:01",
            "name": name,
            "deviceName": name,
            "icon": "audio-headset",
            "uuids": ["0000110b-0000-1000-8000-00805f9b34fb", "00001124-0000-1000-8000-00805f9b34fb"]
        });
        b.phase = "idle";
        return b;
    }

    property var b: null
    property var steps: [() => {
            h.b = typingHeadset("Jabra Elite");
            connections.startConnect(h.b);
            check("first drag pairs", h.b.phase, "connecting");
        }, () => {
            check("held for the user's answer", connections._confirm, h.b.device);
            check("still blocked", h.b.device.blocked, true);
            check("the toast says why, with the guide", ToastService.log, ["pairing-safety"]);
            check("no second note on top of the toast", scene.notes, []);
            check("back out of the belt", [h.b.phase, h.b.shakes, scene.played], ["idle", 1, ["error"]]);
            check("the one-minute wait runs", confirmWait().running, true);
            check("not connected yet", BluetoothService.log.slice(-1), ["pair Jabra Elite"]);
            connections.startConnect(h.b);
        }, () => {
            check("second drag: unblocked", h.b.device.blocked, false);
            check("second drag: question closed", [connections._confirm, confirmWait().running], [null, false]);
            check("second drag: connects", BluetoothService.log.slice(-1), ["connect Jabra Elite"]);
            check("second drag: kept", h.b.device.forgotten, false);
            h.b = typingHeadset("Jabra Evolve");
            connections.startConnect(h.b);
        }, () => {
            check("asked again for a new one", connections._confirm, h.b.device);
            confirmWait().triggered();
            check("no answer within the minute: forgotten", [h.b.device.forgotten, h.b.device.trusted, h.b.device.blocked], [true, false, false]);
            check("no answer: question closed", connections._confirm, null);
        }, () => {
            print(h.failures ? h.failures + " failure(s)" : "all passed");
            Qt.exit(h.failures ? 1 : 0);
        }]
    property int i: 0
    Timer {
        interval: 300
        repeat: true
        running: true
        onTriggered: h.steps[h.i++]()
    }
}
