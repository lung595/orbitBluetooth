import QtQuick
import Quickshell.Io
import "components/volume"

// Test of VolumeTick: where the tick plays when a level changes. One output
// whose own level moved: that sink only; the group's level: every member's
// sink, four at most; nothing inside one 5 % step, nothing when the option is
// off, nothing twice within 45 ms, and a name that is not plain never reaches
// the player. The player is a harmless program and the processes are the
// stand-in of Quickshell.Io listed in ProcessLog. Run with tests/qml/run.sh.
Item {
    id: h

    QtObject {
        id: prefs
        property bool volumeTick: true
    }
    VolumeTick {
        id: tick
        prefs: prefs
        player: "true"
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // The sinks a tick was started in, and the rest of what was run
    function started() {
        return ProcessLog.live.filter(p => p.running);
    }
    function sinks() {
        return started().map(p => p.command[2]);
    }
    // Lets the previous tick end (the processes and the 45 ms limit)
    function settle() {
        ProcessLog.live.forEach(p => p.running = false);
        const end = Date.now() + 60;
        while (Date.now() < end) {}
    }
    function node(name) {
        return {
            "name": name
        };
    }

    Component.onCompleted: {
        check("at rest: nothing runs", started().length, 0);

        tick.play([node("bluez_output.AA_01.1")], 0.5, 0.55);
        check("one output: the tick is in that sink only", h.sinks(), ["bluez_output.AA_01.1"]);
        const run = started()[0].command;
        check("it is the shipped sound, data after --", [run[0], run[1], run[3], run[4].endsWith("sounds/volume.wav")], ["true", "--target", "--", true]);

        h.settle();
        tick.play([node("a.1"), node("b.2"), node("c.3")], 0.5, 0.55);
        check("the group: every member's sink", h.sinks(), ["a.1", "b.2", "c.3"]);

        h.settle();
        tick.play([node("a.1"), node("b.2"), node("c.3"), node("d.4"), node("e.5"), node("f.6")], 0.5, 0.55);
        check("never more than four outputs", h.sinks(), ["a.1", "b.2", "c.3", "d.4"]);

        h.settle();
        tick.play([node("a.1")], 0.5, 0.51);
        check("inside one 5 % step: no tick", h.started().length, 0);

        tick.play([node("a.1")], 0.5, 0.55);
        h.settle();
        check("a tick that ended leaves nothing running", h.started().length, 0);

        tick.play([node("a.1")], 0.5, 0.55);
        const first = h.started().length;
        ProcessLog.live.forEach(p => p.running = false);
        tick.play([node("b.2")], 0.5, 0.55);
        check("a second one within 45 ms is skipped", [first, h.started().length], [1, 0]);

        h.settle();
        tick.play([node("x; rm -rf ~"), null, node("--target=y z"), node("ok.1")], 0.5, 0.55);
        check("a name that is not plain never reaches the player", h.sinks(), ["ok.1"]);

        h.settle();
        prefs.volumeTick = false;
        tick.play([node("a.1")], 0.5, 0.55);
        check("option off: silence", h.started().length, 0);

        print(h.failures ? h.failures + " failure(s)" : "all passed");
        Qt.exit(h.failures ? 1 : 0);
    }
}
