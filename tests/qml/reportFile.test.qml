import QtQuick
import "diagnostics/Redact.js" as Redact
import "diagnostics/ReportFile.js" as ReportFile

// The report file's builder in the engine that will run it: Quickshell's QML
// engine refuses patterns gjs accepts (see Redact.js), so the pure tests of
// tests/reportFile.test.js do not prove the module loads here. Every name and
// address is made up. Run with tests/qml/run.sh.
Item {
    id: h

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    Component.onCompleted: {
        Redact.forget();
        h.check("the file name is dated and plain", ReportFile.fileName(Date.UTC(2026, 9, 8, 12, 3, 41)), "orbit-report-20261008-120341Z.txt");
        const text = ReportFile.build({
            "now": Date.UTC(2026, 9, 8, 12, 3, 41),
            "plugin": "1.16.0",
            "devices": [
                {
                    "name": "Bob's AirPods Pro",
                    "address": "AA:BB:CC:DD:EE:01",
                    "kind": "earbudsStem",
                    "connected": true,
                    "codec": "aac",
                    "battery": 80
                }
            ],
            "journal": ["Oct 08 12:00:00 laptop-jdoe qs[1]: [orbit] ORB-E001 Bob's AirPods Pro AA:BB:CC:DD:EE:01 \x2fhome/jdoe/x"]
        });
        const lines = text.split("\n");
        h.check("the device is written from its allowed facts", lines.filter(l => l.indexOf("kind=") >= 0), ["  device#1 kind=earbudsStem connected=yes codec=aac battery=80"]);
        h.check("its journal line carries the same alias and nothing personal", lines.filter(l => l.indexOf("[orbit]") >= 0), ["  [orbit] ORB-E001 device#1 <mac> ~/x"]);
        h.check("no name, address, login or machine in the file", ["Bob", "AirPods", "AA:BB", "jdoe", "laptop"].filter(w => text.indexOf(w) >= 0), []);
        h.check("a file with nothing is still a report", ReportFile.build(null).split("\n").slice(-5), ["Devices (0 known, 0 connected):", "  none", "Errors and warnings (0 among the 0 events kept):", "  none", ""]);
        // What only this engine can prove: its own patterns, its String.normalize, its lists
        Redact.forget();
        Redact.register("device", " Zoe\u0301's  buds\n");
        h.check("a name is found under its other spellings", Redact.text("on Zo\u00e9\u2019s\u00a0buds: AABBCCDDEE01 access_token=hunter2 ~jdoe"), "on device#1: <mac> access_token=<secret> ~");
        h.check("a device named like a word of its line changes none", ReportFile.devices([
            {
                "name": "aac",
                "kind": "speaker",
                "codec": "aac"
            }
        ])[1], "  device#2 kind=speaker codec=aac");
        h.check("a list that cannot be read takes the journal with it", ReportFile.build({
            "devices": "Bob",
            "journal": ["[orbit] Unlisted Bob"]
        }).indexOf("Unlisted"), -1);
        Redact.forget();
        Redact.register("device", "token");
        Redact.register("device", "1");
        h.check("a device named like a word of a rule lets no secret out, a text is cut before the rules", [Redact.text("token=hunter2 at \x2fhome/jdoe on \uff22ob_1 1.15.0, pins: 3"), Redact.text("a.".repeat(24000)).length], ["device#1=<secret> at ~ on Bob_device#2 1.15.0, pins: 3", 240]);
        h.check("a time out of range still gives a plain name", /^orbit-report-\d{8}-\d{6}Z\.txt$/.test(ReportFile.fileName(8.64e15)), true);
        Redact.forget();
        print(h.failures ? h.failures + " failure(s)" : "all passed");
        Qt.exit(h.failures ? 1 : 0);
    }
}
