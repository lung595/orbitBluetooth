import QtQuick
import Quickshell.Io
import "components/volume"

// Test of VolumeTick: where and when the tick plays when a level changes.
// One output whose own level moved: that sink only; the group's level: every
// member's sink, four at most; one tick per step crossed (5 % or 1 %), the
// first at once and the rest paced on a timer that stops when they are done,
// never more than the cap; a tick is a line on its output's resident player,
// which starts with the first tick, is changed when its output changes and is
// closed after the idle delay; nothing inside one step, nothing when the
// option is off, and a name that is not plain never reaches the player. The
// processes are the stand-in of Quickshell.Io listed in ProcessLog, which
// records what was written to them. Run with tests/qml/run.sh.
Item {
    id: h

    QtObject {
        id: prefs
        property bool volumeTick: true
        property int tickEvery: 5
    }
    VolumeTick {
        id: tick
        prefs: prefs
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
        return started().map(p => p.command[3]);
    }
    // How many ticks were sent to the players, in all
    function ticks() {
        return ProcessLog.live.reduce((n, p) => n + p.written.length, 0);
    }
    // Lets the previous tick end: its processes, what they were sent and the ticks still waiting
    function settle() {
        ProcessLog.live.forEach(p => {
            p.running = false;
            p.written = [];
        });
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
        check("the shipped helper and sound, no shell", [run[0], run[1], run[2].endsWith("tick/orbit_tick.py"), run[4].endsWith("sounds/volume.wav"), run.length], ["python3", "-I", true, true, 5]);
        check("and the tick is a line on its input", started()[0].written, ["t\n"]);

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
        prefs.tickEvery = 1;
        tick.play([node("a.1")], 0.5, 0.55);
        check("1 %: the first tick is at once, four wait", [h.ticks(), tick._pending], [1, 4]);
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

        // The ticks of a run go to the same player: one process, one line each
        tick.play([node("a.1")], 0.5, 0.54);
        tick._fire();
        tick._fire();
        check("a run is one player and one line per tick", [h.started().length, h.ticks()], [1, 3]);

        // The player is closed after the idle delay, then started afresh
        tick._release();
        check("idle: the player's input is closed", started()[0].stdinEnabled, false);
        h.settle();
        tick.play([node("a.1")], 0.5, 0.51);
        check("after it, the next tick starts a player again with its input open", [h.started().length, started()[0].stdinEnabled], [1, true]);

        // The slot of another output is let go; the tick after it starts it afresh
        h.settle();
        tick.play([node("a.1")], 0.5, 0.51);
        tick.play([node("b.2")], 0.5, 0.51);
        check("a slot that served another output is stopped, not given a new target", [h.started().length, h.ticks()], [0, 1]);
        tick.play([node("b.2")], 0.5, 0.51);
        check("the next tick starts it on the new output", h.sinks(), ["b.2"]);
        h.settle();
        prefs.tickEvery = 5;

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
