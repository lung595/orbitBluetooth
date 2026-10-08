import QtQuick
import QtQml
import Quickshell.Io
import qs.Common
import "Volume.js" as Volume

// The soft tick that tells where a level is (sounds/volume.wav), played by
// pw-play in the outputs a change of level reached: the one output whose own
// level moved, or every member's when it is the group's. A tick plays for
// each step crossed (1 % or 5 %, Prefs.tickEvery); a jump is a run of ticks,
// one every Volume.TICK_MS and no more than Volume.MAX_QUEUE of them, so it
// is heard as a run, never swallowed and never a burst at once. A pw-play
// lives for the length of the sound and the pacing timer runs only while
// ticks wait, so nothing runs between two changes.
Item {
    id: tick

    property var prefs: null
    // The program that plays it (a test puts a harmless one)
    property string player: "pw-play"
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
        const idle = _pending === 0;
        _pending = Volume.queued(_pending, crossed);
        if (idle)
            _fire();
    }

    // Plays one waiting tick in every output of the last change. A ring still
    // sounding is left alone: the slots below are all busy only when the
    // pacing outruns the sound, and then that tick is the one dropped.
    function _fire() {
        _pending--;
        Volume.tickSinks(_nodes.map(n => n ? n.name : "")).forEach((name, i) => {
            for (let slot = 0; slot < Volume.OVERLAP; slot++) {
                const process = players.objectAt(i * Volume.OVERLAP + slot);
                if (!process || process.running)
                    continue;
                process.command = [tick.player, "--target", name, "--", tick.path];
                process.running = true;
                return;
            }
        });
    }

    Timer {
        interval: Volume.TICK_MS
        repeat: true
        running: tick.pacing
        onTriggered: tick._fire()
    }

    // Players for every output a tick can reach, idle until they are asked
    Instantiator {
        id: players
        model: Volume.MAX_TICKS * Volume.OVERLAP
        delegate: Process {}
    }
}
