import QtQuick
import Quickshell.Io
import "components/pairing" as Pairing

// Test of ProfileCheck with two pairings at once (audit 2026-11): the second
// check waits for the first instead of taking over its busctl call, so each
// device gets the verdict of its own profiles. Before, the headset's clean
// profiles were read as the keyboard-headset's, which was trusted without a
// question, and the headset never got an answer. busctl is the stand-in of
// Quickshell.Io. Made-up addresses only. Run with tests/qml/run.sh.
Item {
    id: h

    component FakeDevice: QtObject {
        property string dbusPath
        property bool trusted: false
        property bool blocked: false
        property bool forgotten: false
        function forget() {
            forgotten = true;
        }
    }
    FakeDevice {
        id: headset
        dbusPath: "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_41"
    }
    FakeDevice {
        id: typer
        dbusPath: "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_42"
    }
    Pairing.RealProfileCheck {
        id: guard
    }

    readonly property string audio: '{"type":"as","data":["0000110b-0000-1000-8000-00805f9b34fb"]}'
    readonly property string keys: '{"type":"as","data":["0000110b-0000-1000-8000-00805f9b34fb","00001124-0000-1000-8000-00805f9b34fb"]}'
    function busctl() {
        return ProcessLog.live.find(p => p.command[0] === "busctl") || null;
    }
    function answer(text) {
        const p = busctl();
        p.stdout.text = text;
        p.running = false;
        p.exited(0);
    }

    property var verdicts: ({})
    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    readonly property var steps: [
        () => {
            guard.check(headset, "headset", v => h.verdicts.headset = v);
            guard.check(typer, "headset", v => h.verdicts.typer = v);
            check("one busctl at a time, the first device's", busctl().command[5], headset.dbusPath);
            answer(audio);
            check("the first device gets its own verdict", [h.verdicts.headset, h.verdicts.typer], ["ok", undefined]);
        },
        () => {
            check("then the second is read", [busctl().running, busctl().command[5]], [true, typer.dbusPath]);
            answer(keys);
            check("and its key presses are caught", [h.verdicts.typer, typer.blocked, typer.trusted], ["input", true, false]);
            check("the first was left as it was", [headset.blocked, headset.forgotten], [false, false]);
        }
    ]
    property int next: 0
    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: {
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
