import QtQuick
import Quickshell.Io
import "components/volume"

// Test of VolumeTick: where and when the tick plays when a level changes.
// One output whose own level moved: that sink only; the group's level: every
// member's sink, four at most; a change that crosses a step (5 % or 1 %) is
// ONE tick played now, however far it went, and a tick within the gap of the
// last is dropped, never kept for later (live, no queue, no pacing timer); a
// tick is a line "t <gain>" on its output's resident player, the gain falling
// as the output's level rises; the player starts with the first tick, keeps
// its output across neighbouring ticks, is changed when it must serve another
// and is closed after the idle delay; nothing inside one step, at 0 %, nothing
// when the option is off, and a name that is not plain never reaches the
// player. The
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
        // The gap since the last tick is over
        tick._last = 0;
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
        check("and the tick is a line on its input, at full gain at a quiet level", started()[0].written, ["t 1.00\n"]);

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

        // 1 %: a jump of 5 steps is ONE tick, played now (live, nothing waits)
        h.settle();
        prefs.tickEvery = 1;
        tick.play([node("a.1")], 0.5, 0.55);
        check("1 %: a jump of five steps is one tick, now", h.ticks(), 1);

        // A tick within the gap of the last is dropped, not kept for later
        tick.play([node("a.1")], 0.55, 0.56);
        tick.play([node("a.1")], 0.56, 0.57);
        check("a burst inside the gap: the later ticks are dropped", h.ticks(), 1);
        tick._last -= 30;
        tick.play([node("a.1")], 0.57, 0.58);
        check("after the gap the next step ticks again, on the same player", [h.ticks(), h.started().length], [2, 1]);

        h.settle();
        tick.play([node("a.1")], 0.5, 0.504);
        check("1 %: half a percent is no step, no tick", h.started().length, 0);
        h.settle();
        tick.play([node("a.1")], 0.5, 0.51);
        check("1 %: one percent is a tick", h.started().length, 1);

        h.settle();
        tick.play([node("a.1")], 0.1, 0.9);
        check("a sweep of the dial is one tick, not a run", h.ticks(), 1);

        // The level caps the tick: full below the knee, falling above it
        h.settle();
        tick.play([node("a.1")], 0.9, 1.0);
        check("at 100 % the tick is capped (0.60)", started()[0].written, ["t 0.60\n"]);
        h.settle();
        tick.play([node("a.1"), node("b.2")], 0.5, 0.6, [1.0, 0.3]);
        check("a group: each output gets the gain of its own level", h.started().map(p => p.written[0]), ["t 0.60\n", "t 1.00\n"]);
        h.settle();
        tick.play([node("a.1")], 0.02, 0);
        check("down to 0 %: the output is silent, nothing is started", h.started().length, 0);

        // The ticks go to the same player: one process, one line each
        h.settle();
        tick.play([node("a.1")], 0.5, 0.54);
        tick._last = 0;
        tick.play([node("a.1")], 0.5, 0.54);
        check("two ticks are one player and one line each", [h.started().length, h.ticks()], [1, 2]);

        // The player is closed after the idle delay, then started afresh
        tick._release();
        check("idle: the player's input is closed", started()[0].stdinEnabled, false);
        h.settle();
        tick.play([node("a.1")], 0.5, 0.51);
        check("after it, the next tick starts a player again with its input open", [h.started().length, started()[0].stdinEnabled], [1, true]);

        // A member's tick after the group's keeps both players: each output has its own slot
        h.settle();
        tick.play([node("a.1"), node("b.2")], 0.5, 0.51);
        tick._last = 0;
        tick.play([node("b.2")], 0.5, 0.51);
        check("a member after the group: its sink's player, no restart", [h.started().length, h.started().map(p => p.written.length)], [2, [1, 2]]);
        check("only the member's tick went to it, a.1 got nothing more", h.started().filter(p => p.command[3] === "a.1")[0].written.length, 1);

        // A slot that must serve another output is let go; the tick after it starts it afresh
        h.settle();
        for (const n of ["a.1", "b.2", "c.3", "d.4"]) {
            tick._last = 0;
            tick.play([node(n)], 0.5, 0.51);
        }
        tick._last = 0;
        tick.play([node("e.5")], 0.5, 0.51);
        check("with four outputs held, a fifth lets one go", [h.started().length, h.ticks()], [3, 4]);
        tick._last = 0;
        tick.play([node("e.5")], 0.5, 0.51);
        check("the next tick starts it on the new output", h.sinks().indexOf("e.5") >= 0, true);
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
