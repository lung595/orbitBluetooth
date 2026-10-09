import QtQuick
import Quickshell.Io
import "components/pairing"

// Test of the real signal reader (the other tests use a stand-in): one busctl
// per read, reads one at a time and in order, and the caller is always
// answered, also when busctl is not installed (Quickshell then sends neither
// `started` nor `exited`) or fails. Processes are the stand-in of
// Quickshell.Io listed in ProcessLog. Run with tests/qml/run.sh.
Item {
    id: h

    RealSignalRead {
        id: reader
    }

    property int failures: 0
    property var answers: []
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function running() {
        return ProcessLog.live.filter(p => p.running);
    }
    function device(n) {
        return {
            "dbusPath": "/org/bluez/hci0/dev_00_00_00_00_00_0" + n
        };
    }
    function ask(n) {
        reader.read(device(n), rssi => h.answers = h.answers.concat([[n, rssi]]));
    }
    // Ends the running process with this exit code and output
    function end(code, text) {
        const p = running()[0];
        p.started();
        p.stdout.text = text;
        p.running = false;
        p.exited(code);
    }

    // The reader's process is listed once the whole scene is complete
    Component.onCompleted: Qt.callLater(run)

    function run() {
        check("nothing runs until a read is asked for", running().length, 0);

        reader.read({
            "dbusPath": "/etc/passwd"
        }, rssi => h.answers = h.answers.concat([["bad", rssi]]));
        check("a path BlueZ could not have given: no process, no reading", [running().length, h.answers], [0, [["bad", undefined]]]);
        answers = [];

        ask(1);
        ask(2);
        check("two reads in a row: one process at a time", [running().length, running()[0].command.slice(-3)[0]], [1, "/org/bluez/hci0/dev_00_00_00_00_00_01"]);
        end(0, '{"type":"n","data":-40}');
        check("the first answer came, the second read started", [h.answers, running().length, running()[0].command.indexOf("/org/bluez/hci0/dev_00_00_00_00_00_02") > 0], [[[1, -40]], 1, true]);
        end(1, "");
        check("a non-zero exit is no reading, answers keep their order", h.answers, [[1, -40], [2, undefined]]);
        check("nothing is left running", running().length, 0);

        answers = [];
        ask(3);
        ask(4);
        // Program not installed: Quickshell only sets running back to false
        running()[0].running = false;
        check("busctl missing: answered with no reading, the next read goes on", [h.answers, running().length], [[[3, undefined]], 1]);
        end(0, '{"type":"n","data":-55}');
        check("the queue is not stuck after a missing program", [h.answers, running().length], [[[3, undefined], [4, -55]], 0]);

        print(failures === 0 ? "PASS signalRead" : "FAIL signalRead");
        Qt.exit(failures === 0 ? 0 : 1);
    }
}
