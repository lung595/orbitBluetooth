import QtQuick
import "components/volume"

// Test of the order in AudioRoute (D360): every write of a level, whichever
// way it comes (a level, a level per output, a step), says `levelWriting`
// BEFORE the node's volume moves, so DMS's own volume sound is already held
// when DMS sees the change. A spy reads the node's level inside the handler:
// it must still be the old one. Made-up outputs only. Run with tests/qml/run.sh.
Item {
    id: h

    // A sink as Quickshell holds it, cut down to what is written
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

    // The tick is off: nothing is played, only the order is under test
    QtObject {
        id: prefs
        property bool volumeTick: false
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

    // The levels the spy saw at each signal, and how many signals came
    property var seen: []
    Connections {
        target: route
        function onLevelWriting() {
            h.seen = h.seen.concat([[a.audio.volume, b.audio.volume]]);
        }
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    Component.onCompleted: {
        check("at rest: no signal", h.seen, []);

        route.writeLevel(a, 0.8);
        check("a level: signalled once, before it moved", h.seen, [[0.5, 0.5]]);
        check("and then written, unmuted", [a.audio.volume, a.audio.muted], [0.8, false]);

        h.seen = [];
        route.writeLevels([a, b], [0.2, 0.3], 0.8, 0.2);
        check("a level per output: signalled once, before any moved", h.seen, [[0.8, 0.5]]);
        check("and then each has its own", [a.audio.volume, b.audio.volume], [0.2, 0.3]);

        h.seen = [];
        route.stepNode(a, 1);
        check("a step: signalled once, before it moved", h.seen, [[0.2, 0.3]]);
        check("and then moved up by 5 %", Math.round(a.audio.volume * 100), 25);

        h.seen = [];
        route.writeMuted(a, true);
        check("a mute alone is no level: not signalled", h.seen, []);

        print(failures === 0 ? "PASS" : "FAILURES: " + failures);
        Qt.exit(failures === 0 ? 0 : 1);
    }
}
