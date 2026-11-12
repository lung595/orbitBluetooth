import QtQuick
import Quickshell.Io
import "components/pairing" as Pairing

// Test of ProfileCheck with two pairings at once (audit 2026-11): the second
// check waits for the first instead of taking over its busctl call, so each
// device gets the verdict of its own profiles, and a busctl that cannot
// start does not hold the next ones back. Before, the headset's clean
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
    Component {
        id: fakeDevice
        FakeDevice {}
    }
    FakeDevice {
        id: headset
        dbusPath: "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_41"
    }
    FakeDevice {
        id: third
        dbusPath: "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_43"
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
        p.started();
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
            // busctl cannot be started (Quickshell then sends no exit at all)
            guard.check(third, "headset", v => h.verdicts.third = v);
            guard.check(headset, "headset", v => h.verdicts.again = v);
            busctl().running = false;
            check("a busctl that never started: refused, not trusted", [h.verdicts.third, third.forgotten], ["refused", true]);
        },
        () => {
            check("and the next check still runs", [busctl().running, busctl().command[5]], [true, headset.dbusPath]);
            answer(audio);
            check("with its own answer", h.verdicts.again, "ok");
            // Removed by BlueZ while busctl runs (forgotten, adapter gone)
            const gone = fakeDevice.createObject(h, {
                "dbusPath": "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_44"
            });
            guard.check(gone, "headset", v => h.verdicts.gone = v);
            gone.destroy();
        },
        () => {
            answer(keys);
            check("a device gone meanwhile: refused, and nothing throws", h.verdicts.gone, "refused");
        },
        () => {
            // A check that comes after an answer but before the Qt.callLater
            // that answer left: it starts its busctl at once, and the late
            // callLater must not launch it again. In Quickshell a second
            // launch during a run runs the command once more, and that
            // answer was read for the next device: the one that types got
            // "ok" on the other's profiles
            guard.check(headset, "headset", v => h.verdicts.first = v);
            answer(audio);
            h.late = fakeDevice.createObject(h, {
                "dbusPath": "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_45"
            });
            h.typing = fakeDevice.createObject(h, {
                "dbusPath": "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_46"
            });
            guard.check(h.late, "headset", v => h.verdicts.late = v);
            busctl().started();
            guard.check(h.typing, "headset", v => h.verdicts.typing = v);
        },
        () => {
            // The late device's busctl ends; it started long ago, so no
            // second `started`
            const p = busctl();
            p.stdout.text = audio;
            p.running = false;
            p.exited(0);
            check("a check between an answer and its callLater: its own verdict, the next one waits", [h.verdicts.late, h.verdicts.typing, h.late.forgotten], ["ok", undefined, false]);
        },
        () => {
            check("and the next device is read on its own call", [busctl().running, busctl().command[5]], [true, h.typing.dbusPath]);
            answer(keys);
            check("so its key presses are caught", [h.verdicts.typing, h.typing.blocked, h.typing.trusted], ["input", true, false]);
        }
    ]
    property QtObject late: null
    property QtObject typing: null
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
