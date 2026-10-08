import QtQuick
import Quickshell.Io
import "components/common"

// Test of the report and its copy: nothing runs until a report is asked for;
// a request reads the CPU ticks, waits a second, runs the five short tools one
// after the other and builds the report from their answers, with the shell's
// CPU, the settings that choose a behaviour and no name, path or address. The
// copy tries wl-copy --sensitive first with the text on its standard input,
// falls back to DMS's own copy, and says so when neither works. Processes are
// the stand-in of Quickshell.Io listed in ProcessLog. Run with tests/qml/run.sh.
Item {
    id: h

    QtObject {
        id: prefs
        property bool sounds: true
        property int maxDevices: 8
        property string holeStyle: "blackhole"
        // Not a reportable setting: must never appear
        property string imageFolder: "/home/bob/Pictures"
        property bool reduceMotion: false
    }
    ReportService {
        id: svc
        prefs: prefs
        surfaces: ({
                "settings": true
            })
    }
    ReportCopy {
        id: copier
    }

    property int failures: 0
    property string built: ""
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function running() {
        return ProcessLog.live.filter(p => p.running);
    }
    // Lets the process the service runs now end with this answer
    function answer(text) {
        const p = running()[0];
        const program = p.command[0];
        p.started();
        p.stdout.text = text;
        p.running = false;
        p.exited(0);
        return program;
    }
    // The stand-in FileView of /proc/self/stat is the one that is not blocking
    function statFile() {
        for (let i = 0; i < svc.data.length; i++)
            if (svc.data[i].content !== undefined && !svc.data[i].blockLoading)
                return svc.data[i];
        return null;
    }

    Connections {
        target: svc
        function onBuilt(text) {
            h.built = text;
        }
    }

    readonly property var tools: ({
            "dms": "dms v1.6.3",
            "quickshell": "Quickshell 0.3.1 (revision , distributed by Someone)",
            "niri": "niri 26.04 (8ed0da4)",
            "rpm": "6.11.2",
            "cat": "NAME=\"Fedora Linux\"\nPRETTY_NAME=\"Fedora Linux 44 (Workstation Edition)\"\n",
            "journalctl": "Oct 08 12:00:00 bobs-pc qs[1]: [orbit] ORB-E001 failed at /home/bob/.cache/x\nOct 08 12:00:01 bobs-pc qs[1]: unrelated line"
        })

    // After the one-second window: the tools, then the copy
    Timer {
        id: afterWindow
        interval: 1150
        onTriggered: {
            const asked = [];
            while (h.running().length > 0 && asked.length < 10) {
                const program = h.running()[0].command[0];
                asked.push(program);
                h.answer(h.tools[program] || "");
            }
            h.check("the tools ran one after the other", asked, ["dms", "quickshell", "niri", "rpm", "cat", "journalctl"]);
            h.check("the request ended", [svc.busy, svc.report === h.built, h.built.length > 100], [false, true, true]);
            h.check("versions, surfaces and the shell's CPU are in", [/DMS +: 1\.6\.3 +Quickshell : 0\.3\.1 +Qt : 6\.11\.2/.test(h.built), /Surfaces +: settings \(active\)/.test(h.built), /CPU +: 1[0-9](\.\d)?% of one core, whole shell/.test(h.built)], [true, true, true]);
            h.check("a setting that chooses a behaviour is in, one that holds a path is not", [/sounds=yes/.test(h.built), /holeStyle=blackhole/.test(h.built), /imageFolder|Pictures/.test(h.built)], [true, true, false]);
            h.check("the journal keeps Orbit's line, cleaned, and drops the rest", [/\[orbit\] ORB-E001 failed at ~\//.test(h.built), /bob|unrelated/.test(h.built)], [true, false]);
            h.check("the request was recorded as an event", /ORB-I030 via=ipc/.test(h.built), true);
            h.check("the report is handed over once", [svc.takeReport() === h.built, svc.takeReport()], [true, ""]);
            h.copyTests();
        }
    }

    function copyTests() {
        copier.copy("REPORT");
        const first = running()[0];
        check("the sensitive copy is tried first, text not on the command line", [first.command, first.command.join(" ").indexOf("REPORT") < 0], [["wl-copy", "--sensitive"], true]);
        first.started();
        check("the text goes in by standard input, which is then closed", [first.written, first.stdinEnabled], [["REPORT"], false]);
        first.running = false;
        first.exited(1);
        const second = running()[0];
        check("wl-copy refuses: DMS's own copy takes over", second.command, ["dms", "clipboard", "copy"]);
        second.started();
        second.running = false;
        second.exited(0);
        check("copied by the fallback: said so", [copier.result, copier.inHistory], ["copied", true]);
        copier.copy("AGAIN");
        let tool = running()[0];
        tool.started();
        tool.running = false;
        tool.exited(0);
        check("copied by wl-copy: not in the history", [copier.result, copier.inHistory], ["copied", false]);
        copier.copy("NONE");
        for (let i = 0; i < 2; i++) {
            tool = running()[0];
            tool.started();
            tool.running = false;
            tool.exited(1);
        }
        check("both refuse: a guided state, nothing running", [copier.result, running().length], ["none", 0]);
        // Quickshell sends neither `started` nor `exited` for a program that is
        // not installed: `running` just goes back to false
        copier.copy("ABSENT");
        for (let i = 0; i < 2; i++)
            running()[0].running = false;
        check("neither tool installed: the same guided state, nothing running", [copier.result, running().length], ["none", 0]);
        copier.copy("AGAIN");
        check("a new copy is not refused afterwards", running().length, 1);
        running()[0].running = false;
        running()[0].running = false;
        missingProbe();
    }

    // A tool that is not installed (rpm off Fedora) must not stop the report
    function missingProbe() {
        check("a second request starts", svc.request("ipc"), true);
        afterMissing.start();
    }

    Timer {
        id: afterMissing
        interval: 1150
        onTriggered: {
            let missed = 0;
            while (h.running().length > 0 && missed < 10) {
                const p = h.running()[0];
                if (p.command[0] === "rpm") {
                    p.running = false;
                    missed++;
                } else {
                    h.answer(h.tools[p.command[0]] || "");
                }
            }
            h.check("a missing tool: the request still ends with the others' answers", [missed, svc.busy, /DMS +: 1\.6\.3/.test(h.built)], [1, false, true]);
            h.end();
        }
    }

    function end() {
        print(h.failures ? h.failures + " failure(s)" : "all passed");
        Qt.exit(h.failures ? 1 : 0);
    }

    Component.onCompleted: {
        statFile().content = "1 (qs) S 0 0 0 0 0 0 0 0 0 0 100 50";
        h.check("at rest: nothing runs and nothing is built", [h.running().length, svc.busy, svc.report], [0, false, ""]);
        h.check("a request starts", svc.request("ipc"), true);
        h.check("a second request while busy is refused", svc.request("ipc"), false);
        h.check("busy during the window, no tool yet", [svc.busy, h.running().length], [true, 0]);
        // 15 more ticks of the shell by the end of the window
        statFile().content = "1 (qs) S 0 0 0 0 0 0 0 0 0 0 110 55";
        afterWindow.start();
    }
}
