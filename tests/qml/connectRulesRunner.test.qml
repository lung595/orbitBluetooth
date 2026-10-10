import QtQuick
import "components/rules"
import "components/rules/ConnectRules.js" as Rules

// Test of the connection rules runner: the start volume is requested before the
// noise mode, an action the device cannot do is relayed with its reason, a
// storm requests once, and a missing rule table does nothing. Run with
// tests/qml/run.sh.
Item {
    id: t

    readonly property string addr: "02:00:00:00:40:01"
    property int failures: 0
    property var log: []

    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    ConnectRulesRunner {
        id: runner
        salt: "test-salt"
        onVolumeRequested: (address, value) => t.log.push("volume:" + value)
        onNoiseRequested: (address, mode) => t.log.push("noise:" + mode)
        onSkipped: (address, kind, reason) => t.log.push("skip:" + kind + ":" + reason)
    }

    Component.onCompleted: {
        const full = {
            "volume": true,
            "noiseModes": ["nc", "off"]
        };
        runner.deviceConnected(addr, full);
        check("no rules table: nothing", t.log, []);

        const rules = {};
        rules[Rules.keyOf(addr, "test-salt")] = {
            "noise": "nc",
            "volume": 30
        };
        runner.rules = rules;
        runner.deviceConnected(addr, full);
        check("volume before noise", t.log, ["volume:30", "noise:nc"]);

        t.log = [];
        runner.deviceConnected(addr, full);
        check("storm requests nothing again", t.log, ["skip:all:storm"]);

        t.log = [];
        const other = "02:00:00:00:40:02";
        rules[Rules.keyOf(other, "test-salt")] = {
            "noise": "ambient"
        };
        runner.rules = rules;
        runner.deviceConnected(other, full);
        check("unsupported mode relayed", t.log, ["skip:noise:unsupported"]);

        Qt.callLater(() => {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
        });
    }
}
