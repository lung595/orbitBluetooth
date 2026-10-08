import QtQuick
import "components/scene"
import "components/together"

// Test of the names a Listen together says (value 10): a wired output that was
// unplugged is gone from PipeWire, yet the note that says so still names it,
// because the session kept its name while it was a member; what is kept goes
// when the output leaves or the session ends; and every name is one clean line
// (a control character or a bidi override from a device never reaches a note or
// an answer of the command line, value 11). The scene says it in the wired
// output's own words: unplugged, not plugged in. Run with tests/qml/run.sh.
Item {
    id: h

    // A fake AudioRoute: a Bluetooth device and wired outputs, each replaced
    // as a whole when one changes
    QtObject {
        id: route
        property var devices: ({})
        property var wired: ({})
        function known(address) {
            return devices[address] || null;
        }
        function wiredSink(name) {
            return wired[name] || null;
        }
        function wiredFilter(name) {
            return null;
        }
        function deviceNode(device) {
            return null;
        }
        function pcNode(device) {
            return device.pc || device.sink;
        }
    }
    TogetherSession {
        id: session
        route: route
    }
    // The scene as Listen together in the orbit sees it: the notes it is told
    // to say are kept, as [title, hint, anchor]
    property var said: []
    QtObject {
        id: scene
        property bool active: true
        property var deviceMap: ({})
        property var audioRoute: QtObject {
            property var together: session
        }
        function explain(note) {
            h.said.push([note.title, note.hint, note.anchor]);
        }
    }
    OrbitTogether {
        id: together
        scene: scene
    }

    readonly property string phones: "AA:BB:CC:DD:EE:01"
    readonly property string w1: "alsa_output.test_one"
    readonly property string w2: "alsa_output.test_two"

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // What the notes would have been told: the name asked for at the moment each
    // signal is heard, as the scene and the command line ask for it
    property var heard: []
    Connections {
        target: session
        function onEnded(why, address) {
            h.heard.push(["ended", why, session.nameOf(address)]);
        }
        function onMemberLeft(address) {
            h.heard.push(["left", session.nameOf(address)]);
        }
    }

    function plug(name) {
        route.devices = {
            [h.phones]: {
                "name": name,
                "connected": true,
                "sink": {
                    "name": "bluez_output.AA_BB_CC_DD_EE_01.1",
                    "properties": {
                        "api.bluez5.profile": "a2dp-sink"
                    }
                }
            }
        };
    }
    function wire(name, description) {
        const next = Object.assign({}, route.wired);
        next[name] = {
            "name": name,
            "description": description,
            "nickname": "",
            "audio": {
                "volume": 1,
                "muted": false
            }
        };
        route.wired = next;
    }
    function unwire(name) {
        const next = Object.assign({}, route.wired);
        delete next[name];
        route.wired = next;
    }

    // One step after another, each after the loop has turned (a member that
    // goes is noticed on the next turn)
    property int stage: 0
    Timer {
        id: turn
        interval: 60
        onTriggered: {
            h.stage++;
            h["step" + h.stage]();
        }
    }
    function wait() {
        turn.start();
    }

    Component.onCompleted: {
        plug("Headset");
        wire(w1, "Studio\u0007 Interface");
        wire(w2, "Desk‮ Speakers");

        // A name is one clean line, as short as a card shows it
        check("a wired output's name is cleaned", [session.nameOf(w1), session.nameOf(w2)], ["Studio Interface", "Desk Speakers"]);
        plug("Head\u001b[31mset‮\u0007 " + "x".repeat(60));
        check("a device's name is cleaned and cut too", session.nameOf(phones), "Head [31mset " + "x".repeat(27));
        check("a name that is not there is nothing", [session.nameOf("alsa_output.test_gone"), session.nameOf("AA:BB:CC:DD:EE:99")], ["", ""]);
        plug("Headset");

        // --- Two members: the wired one is unplugged, the session ends with it -----------------
        check("start with a wired output and a Bluetooth one", session.start([w1, phones]), null);
        unwire(w1);
        check("unplugged but still a member: it is still named", session.nameOf(w1), "Studio Interface");
        wait();
    }

    function step1() {
        check("the session ended with it, and the note could name it", [session.active, h.heard], [false, [["ended", "member-left", "Studio Interface"]]]);
        check("the scene says it was unplugged, in its words", h.said, [["Studio Interface was unplugged", "Listening together ended with it", "wired-outputs"]]);
        check("the session is over: nothing is kept", session.nameOf(w1), "");
        h.said = [];

        // --- Three members: one wired output is unplugged, the others go on --------------------
        h.heard = [];
        wire(w1, "Studio Interface");
        check("start with two wired outputs and a Bluetooth one", session.start([w1, phones, w2]), null);
        unwire(w2);
        wait();
    }

    function step2() {
        check("the others go on, and the note could name the one that left", [session.active, session.members, h.heard], [true, [w1, phones], [["left", "Desk Speakers"]]]);
        check("the scene says it was unplugged and that the others go on", h.said, [["Desk Speakers was unplugged", "The others keep listening together", "wired-outputs"]]);
        check("it left: its name is not kept any longer", session.nameOf(w2), "");
        check("the one that stays is named", session.nameOf(w1), "Studio Interface");

        // --- One joins after the session began -------------------------------------------------
        wire(w2, "Desk Speakers");
        check("a wired output joins", session.add([w2]), null);
        unwire(w2);
        check("it is kept from when it joined", session.nameOf(w2), "Desk Speakers");
        session.remove(w2);
        check("it leaves by the user's request: not kept", session.nameOf(w2), "");

        // --- The user ends it ------------------------------------------------------------------
        unwire(w1);
        h.said = [];
        session.end("ended", "");
        check("what the user asked for needs no note", h.said, []);
        wait();
    }

    function step3() {
        check("nothing is kept once the session is over", [session.nameOf(w1), session.nameOf(w2)], ["", ""]);

        // --- A drop that cannot be done says so in the output's words ---------------------------
        h.said = [];
        wire(w1, "Studio Interface");
        plug("Headset");
        check("an output that is gone is not plugged in, even with no name to give", together.hint({
            "address": w1
        }, {
            "address": "alsa_output.test_gone"
        }), "This output is not plugged in");
        check("a Bluetooth device that is gone is not connected", together.hint({
            "address": phones
        }, {
            "address": "AA:BB:CC:DD:EE:99"
        }), "This device is not connected");
        print(h.failures ? h.failures + " failure(s)" : "all passed");
        Qt.exit(h.failures ? 1 : 0);
    }
}
