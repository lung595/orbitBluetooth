import QtQuick
import qs.Common
import "components/settings"

// Test of WidgetSketch (audit 2026-11): the drawing's clock is a plain Timer,
// never a running QML animation (which redraws the whole shell, CONTRIBUTING
// "Never loop a QML animation"). It moves only while it can be seen: a hidden
// parent, `running: false` or Reduce motion stop it on the finished picture.
// Run with tests/qml/run.sh.
Item {
    id: h
    width: 200
    height: 200

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    Item {
        id: holder
        WidgetSketch {
            id: sketch
            kind: "cc"
        }
    }

    property real seen: 0
    readonly property var steps: [
        () => {
            seen = sketch.t;
        },
        () => {
            check("the clock moves while it shows", sketch.t !== seen, true);
            holder.visible = false;
        },
        () => {
            check("a hidden parent stops it on the finished picture", sketch.t, sketch.still);
            holder.visible = true;
            sketch.running = false;
        },
        () => {
            check("running false: the finished picture", sketch.t, sketch.still);
            sketch.running = true;
            SettingsData.reduceMotion = true;
        },
        () => {
            check("Reduce motion: the finished picture", sketch.t, sketch.still);
            SettingsData.reduceMotion = false;
        }
    ]
    property int at: 0
    Timer {
        id: clock
        interval: 150
        onTriggered: h.next()
    }
    function next() {
        if (at >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        steps[at++]();
        clock.start();
    }
    Component.onCompleted: clock.start()
}
