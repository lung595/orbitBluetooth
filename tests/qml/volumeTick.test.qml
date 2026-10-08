import QtQuick
import Quickshell.Io
import "components/volume"

// Test of VolumeTick: where and when the tick plays when a level changes.
// One output whose own level moved: that sink only; the group's level: every
// member's sink, four at most; one tick per step crossed (5 % or 1 %), the
// first at once and the rest paced on a timer that stops when they are done,
// never more than the cap; nothing inside one step, nothing when the option is
// off, and a name that is not plain never reaches the player. The player is a
// harmless program and the processes are the stand-in of Quickshell.Io listed
// in ProcessLog. Run with tests/qml/run.sh.
Item {
    id: h

    QtObject {
        id: prefs
        property bool volumeTick: true
        property string tickEvery: "5"
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
    // Lets the previous tick end: its processes and the ticks still waiting
    function settle() {
        ProcessLog.live.forEach(p => p.running = false);
        tick._pending = 0;
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

        // 1 %: a jump of 5 steps is 5 ticks, the first now, the others paced
        h.settle();
        prefs.tickEvery = "1";
        tick.play([node("a.1")], 0.5, 0.55);
        check("1 %: the first tick is at once, four wait", [h.started().length, tick._pending], [1, 4]);
        check("the pacing timer runs while ticks wait", tick.pacing, true);

        h.settle();
        tick.play([node("a.1")], 0.5, 0.504);
        check("1 %: half a percent is no step, no tick", h.started().length, 0);
        h.settle();
        tick.play([node("a.1")], 0.5, 0.51);
        check("1 %: one percent is a tick", h.started().length, 1);

        h.settle();
        tick.play([node("a.1")], 0.1, 0.9);
        check("a sweep of the dial waits for no more than the cap", tick._pending, 11);

        h.settle();
        check("when none waits the timer is stopped: nothing runs at rest", tick.pacing, false);

        // Two ticks of the same output ring together, up to the overlap
        tick.play([node("a.1")], 0.5, 0.52);
        tick._fire();
        tick._fire();
        check("ticks overlapping in one output use its slots", h.started().length, 3);
        h.settle();
        prefs.tickEvery = "5";

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
