import QtQuick
import Quickshell.Io
import "components/volume"

// Test of where AudioRoute plays the volume tick (NAK-211): a level written to
// one output ticks in that output alone, a level per output (the group's
// general level) ticks in each of them, and a member's own level never reaches
// its neighbours. The processes are the stand-in of Quickshell.Io listed in
// ProcessLog. Made-up outputs only. Run with tests/qml/run.sh.
Item {
    id: h

    component Sink: QtObject {
        property string name: ""
        property QtObject audio: QtObject {
            property real volume: 0.5
            property bool muted: true
        }
    }
    Sink {
        id: a
        name: "bluez_output.AA_01.1"
    }
    Sink {
        id: b
        name: "bluez_output.AA_02.1"
    }

    QtObject {
        id: prefs
        property bool volumeTick: true
        property int tickEvery: 5
        property bool tickAlone: true
        property bool separatePc: true
        property var pcLevels: ({})
        property string volumeSteps: "fixed"
        property int volumeStep: 5
        property string volumeSpeed: "balanced"
        property int togetherFineDelay: 0
    }
    AudioRoute {
        id: route
        prefs: prefs
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // What each running player was sent, by sink
    function heard() {
        const out = {};
        ProcessLog.live.filter(p => p.running).forEach(p => out[p.command[3]] = p.written);
        return out;
    }
    function settle() {
        ProcessLog.live.forEach(p => {
            p.running = false;
            p.written = [];
        });
    }

    // Each step waits out the tick's gap (25 ms) after the previous one
    property int stepIndex: 0
    readonly property var steps: [() => {
            check("at rest: nothing runs", ProcessLog.live.filter(p => p.running).length, 0);
            route.writeLevel(a, 0.8);
        }, () => {
            check("one output's level: its sink alone, at the capped gain", heard(), {
                "bluez_output.AA_01.1": ["t 0.75\n"]
            });
            settle();
            route.writeLevels([a, b], [0.4, 1.0], 0.5, 0.7);
        }, () => {
            check("the group's general level: each member, at the gain of its own level", heard(), {
                "bluez_output.AA_01.1": ["t 1.00\n"],
                "bluez_output.AA_02.1": ["t 0.60\n"]
            });
            settle();
            route.writeLevel(b, 0.2);
        }, () => {
            check("then a member's own level: that member only", Object.keys(heard()), ["bluez_output.AA_02.1"]);
            settle();
            route.writeLevel(a, 0);
        }, () => {
            check("a level down to 0 %: silent, nothing started", heard(), {});
            print(failures === 0 ? "PASS" : "FAILURES: " + failures);
            Qt.exit(failures === 0 ? 0 : 1);
        }]
    Timer {
        interval: 40
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: h.steps[h.stepIndex++]()
    }
}
