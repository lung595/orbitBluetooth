import QtQuick
import "components/volume"

// Test of AudioRoute's writes of a level, whichever way it comes (a level, a
// level per output, a step): each lands on its node, unmuted, and a mute moves
// no level. Made-up outputs only. Run with tests/qml/run.sh.
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

    QtObject {
        id: prefs
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

    Component.onCompleted: {
        route.writeLevel(a, 0.8);
        check("a level is written, unmuted", [a.audio.volume, a.audio.muted], [0.8, false]);
        check("and only to its node", [b.audio.volume, b.audio.muted], [0.5, true]);

        route.writeLevels([a, b], [0.2, 0.3]);
        check("a level per output: each has its own", [a.audio.volume, b.audio.volume], [0.2, 0.3]);
        check("and each is unmuted", [a.audio.muted, b.audio.muted], [false, false]);

        route.stepNode(a, 1);
        check("a step moves up by 5 %", Math.round(a.audio.volume * 100), 25);

        route.writeMuted(a, true);
        check("a mute moves no level", [a.audio.muted, Math.round(a.audio.volume * 100)], [true, 25]);

        print(failures === 0 ? "PASS" : "FAILURES: " + failures);
        Qt.exit(failures === 0 ? 0 : 1);
    }
}
