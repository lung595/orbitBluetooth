import QtQuick
import QtQml
import Quickshell.Io
import qs.Common
import "Volume.js" as Volume

// The soft tick that tells where a level is (sounds/volume.wav), played in the
// outputs a change of level reached: the one output whose own level moved, or
// every member's when it is the group's. A tick plays for each step crossed
// (1 % or 5 %, Prefs.tickEvery); a jump is a run of ticks, one every
// Volume.TICK_MS and no more than Volume.MAX_QUEUE of them, so it is heard as
// a run and never as a burst at once.
// A player per output (tick/orbit_tick.py) holds ONE PipeWire stream and mixes
// every tick sent to it as a line on its standard input: a pw-play per tick
// cost a process, a connection and a stream each, too much at 40 a second. It
// starts with the first tick, goes after Volume.IDLE_MS without one (closing
// its standard input) and dies with the shell. The pacing timer runs only
// while ticks wait, so nothing runs between two changes.
Item {
    id: tick

    property var prefs: null
    readonly property string helper: Paths.strip(Qt.resolvedUrl("../../tick/orbit_tick.py"))
    readonly property string path: Paths.strip(Qt.resolvedUrl("../../sounds/volume.wav"))
    // Ticks waiting for their turn, and the outputs the last change reached
    property int _pending: 0
    property var _nodes: []
    // Whether the pacing timer runs (only while ticks wait)
    readonly property bool pacing: _pending > 0

    // `nodes` are the PipeWire sinks the change reached, `before` and `after` the level it went from and to
    function play(nodes, before, after) {
        if (!prefs || !prefs.volumeTick)
            return;
        const crossed = Volume.stepsCrossed(before, after, Volume.stepSize(prefs.tickEvery));
        if (!crossed)
            return;
        _nodes = nodes;
        // The first one is heard at once, the rest follow on the timer
        const first = _pending === 0;
        _pending = Volume.queued(_pending, crossed);
        if (first)
            _fire();
    }

    // Sends one waiting tick to the player of every output of the last change
    function _fire() {
        if (_pending <= 0)
            return;
        _pending--;
        Volume.tickSinks(_nodes.map(n => n ? n.name : "")).forEach((name, i) => {
            const player = players.objectAt(i);
            if (!player)
                return;
            if (player.running && (player.sink !== name || !player.stdinEnabled)) {
                // The slot served another output, or is closing: let it go, the next tick starts it afresh
                player.running = false;
                return;
            }
            if (!player.running) {
                player.sink = name;
                player.command = ["python3", "-I", tick.helper, name, tick.path];
                player.stdinEnabled = true;
                player.running = true;
            }
            player.write("t\n");
        });
        idle.restart();
    }

    // Closing the standard input lets a player finish the ticks still ringing, then exit
    function _release() {
        for (let i = 0; i < Volume.MAX_TICKS; i++) {
            const player = players.objectAt(i);
            if (player && player.running)
                player.stdinEnabled = false;
        }
    }

    Timer {
        interval: Volume.TICK_MS
        repeat: true
        running: tick.pacing
        onTriggered: tick._fire()
    }

    // One shot, armed by each tick: never ticks while nothing plays
    Timer {
        id: idle
        interval: Volume.IDLE_MS
        onTriggered: tick._release()
    }

    // One player per output a tick can reach, not started until asked
    Instantiator {
        id: players
        model: Volume.MAX_TICKS
        delegate: Process {
            property string sink: ""
        }
    }
}
