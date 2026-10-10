import QtQuick
import QtQml
import Quickshell.Io
import qs.Common
import "Volume.js" as Volume

// The soft tick that tells where a level is (sounds/volume.wav), played in the
// outputs a change of level reached: the one output whose own level moved, or
// every member's when it is the group's. It is LIVE: a change that crosses a
// step (1 % or 5 %, Prefs.tickEvery) plays one tick now, however far it
// went, and one that comes within Volume.MIN_GAP_MS of the last is dropped,
// never kept for later, so the sound follows the hand and ends with it. Each
// tick carries a gain that falls as the output's level rises (Volume.tickGain)
// so it cannot saturate.
// A player per output (tick/orbit_tick.py) holds ONE PipeWire stream, fades
// each tick in and out and lets a new tick replace the one still ringing: a
// pw-play per tick cost a process, a connection and a stream each, too much at
// 20 a second. It starts with the first tick, goes after Volume.IDLE_MS
// without one (closing its standard input) and dies with the shell. Nothing
// here runs between two changes: no pacing timer, only the idle one-shot.
Item {
    id: tick

    property var prefs: null
    readonly property string helper: Paths.strip(Qt.resolvedUrl("../../tick/orbit_tick.py"))
    readonly property string path: Paths.strip(Qt.resolvedUrl("../../sounds/volume.wav"))
    // When the last tick played (ms), to keep to Volume.MIN_GAP_MS
    property double _last: 0

    // `nodes` are the sinks the change reached ({name, bypass}, Route.tickOutput), `before` and `after` the level it went from and to,
    // `levels` (optional) the level each of the nodes now has, `after` for all when omitted
    function play(nodes, before, after, levels) {
        if (!prefs || !prefs.volumeTick)
            return;
        if (!Volume.stepsCrossed(before, after, Volume.stepSize(prefs.tickEvery)))
            return;
        const now = Date.now();
        if (!Volume.due(now, _last))
            return;
        _last = now;
        const targets = Volume.tickTargets(nodes.map((n, i) => ({
                    "name": n ? n.name : "",
                    "bypass": !!(n && n.bypass),
                    "level": levels ? levels[i] : after
                })));
        const held = [];
        for (let i = 0; i < Volume.MAX_TICKS; i++) {
            const p = players.objectAt(i) as Player;
            held.push(p && p.running ? p.sink : "");
        }
        const slots = Volume.slotsFor(held, targets.map(t => t.name));
        targets.forEach((t, k) => _send(players.objectAt(slots[k]), t));
        idle.restart();
    }

    // Sends one tick to the player of one output
    function _send(player, target) {
        if (!player)
            return;
        if (player.running && (player.sink !== target.name || !player.stdinEnabled)) {
            // The slot served another output, or is closing: let it go, the next tick starts it afresh
            player.running = false;
            return;
        }
        if (!player.running) {
            player.sink = target.name;
            player.command = ["python3", "-I", tick.helper, target.name, tick.path];
            player.stdinEnabled = true;
            player.running = true;
        }
        player.write("t " + target.gain.toFixed(2) + "\n");
    }

    // Closing the standard input lets a player finish the tick still ringing, then exit
    function _release() {
        for (let i = 0; i < Volume.MAX_TICKS; i++) {
            const player = players.objectAt(i) as Player;
            if (player && player.running)
                player.stdinEnabled = false;
        }
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
        delegate: Player {}
    }

    // A tick player and the output it is open on
    component Player: Process {
        property string sink: ""
    }
}
