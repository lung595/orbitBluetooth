import QtQuick
import Quickshell.Services.Pipewire
import "components/scene"

// Test of the shared-radio note (D293, P170): it watches nothing while fewer
// than two outputs of the adapter exist, says once per pair that two outputs
// playing at once share one radio (never again for the same pair, never for
// an output of another adapter, only while the orbit is open and then as soon
// as it opens), and goes quiet with one output. PipeWire is the mock's: the
// outputs and link groups are set by hand. Run with tests/qml/run.sh radio.
Item {
    id: h

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string receiver: "02:00:00:00:20:01"
    readonly property string speaker: "02:00:00:00:20:02"
    readonly property string stranger: "02:00:00:00:30:09"

    // The part of the scene OrbitRadio reads: the adapter's devices, whether
    // the orbit is open, and where the note goes
    QtObject {
        id: scene
        property bool active: true
        property var notes: []
        property var adapter: ({
                "devices": {
                    "values": [
                        {
                            "address": h.headset
                        },
                        {
                            "address": h.receiver
                        },
                        {
                            "address": h.speaker
                        }
                    ]
                }
            })
        function explain(info) {
            notes = notes.concat([info]);
        }
    }
    OrbitRadio {
        id: radio
        scene: scene
    }

    function sink(address) {
        return {
            "name": "bluez_output." + address.replace(/:/g, "_") + ".1",
            "isSink": true,
            "isStream": false
        };
    }
    // A link group feeding an output, running or paused
    function link(address, running) {
        return {
            "state": running ? PwLinkState.Active : PwLinkState.Paused,
            "target": sink(address)
        };
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    function quiet() {
        // The mock starts with the headset's sink only
        check("one output: nothing watched", [radio.watching, radio.pair, scene.notes.length], [false, "", 0]);
        Pipewire.links = [link(headset, true)];
        check("one output playing says nothing", scene.notes.length, 0);
        // An output of another adapter is not ours: it has its own radio
        Pipewire.extraSinks = [sink(stranger)];
        Pipewire.links = [link(headset, true), link(stranger, true)];
        check("another adapter's output is not counted", [radio.watching, radio.pair, scene.notes.length], [false, "", 0]);
    }

    function pairTold() {
        Pipewire.extraSinks = [sink(receiver)];
        Pipewire.links = [link(headset, true), link(receiver, false)];
        check("two outputs exist, one plays: watched, silent", [radio.watching, radio.pair, scene.notes.length], [true, "", 0]);
        Pipewire.links = [link(headset, true), link(receiver, true)];
        check("both play: the pair is named", radio.pair, headset + "+" + receiver);
        check("and said, once", scene.notes.length, 1);
        const note = scene.notes[0];
        check("the note says what and where to read", [note.title, note.anchor], ["Two outputs share one Bluetooth radio", "two-outputs-one-radio"]);
        // The receiver rests, then plays again: the same pair is not told twice
        Pipewire.links = [link(headset, true), link(receiver, false)];
        Pipewire.links = [link(headset, true), link(receiver, true)];
        check("the same pair is not told again", scene.notes.length, 1);
    }

    function closedOrbit() {
        // A new pair while the orbit is closed waits for it to open
        Pipewire.links = [];
        Pipewire.extraSinks = [sink(receiver), sink(speaker)];
        scene.active = false;
        Pipewire.links = [link(receiver, true), link(speaker, true)];
        check("orbit closed: no note", scene.notes.length, 1);
        scene.active = true;
        check("orbit opens on the pair: told", scene.notes.length, 2);
        scene.active = false;
        scene.active = true;
        check("reopening says nothing more", scene.notes.length, 2);
    }

    function leaving() {
        Pipewire.extraSinks = [];
        Pipewire.links = [link(headset, true)];
        check("back to one output: nothing watched", [radio.watching, radio.pair], [false, ""]);
    }

    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 20000
        running: true
        onTriggered: {
            print("FAIL timed out: a step threw");
            Qt.exit(1);
        }
    }

    Component.onCompleted: {
        quiet();
        pairTold();
        closedOrbit();
        leaving();
        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
