import QtQuick
import QtQml
import Quickshell.Io
import qs.Common
import "Volume.js" as Volume

// The soft tick that tells where a level is (sounds/volume.wav), played by
// pw-play in the outputs a change of level reached: the one output whose own
// level moved, or every member's when it is the group's. A tick plays only
// when the level crosses a 5 % step and never more than one in 45 ms; a
// pw-play lives for the length of the sound, so nothing runs between two.
Item {
    id: tick

    property var prefs: null
    // The program that plays it (a test puts a harmless one)
    property string player: "pw-play"
    readonly property string path: Paths.strip(Qt.resolvedUrl("../../sounds/volume.wav"))
    property double _last: 0

    // `nodes` are the PipeWire sinks the change reached, `before` and `after` the level it went from and to
    function play(nodes, before, after) {
        if (!prefs || !prefs.volumeTick || !Volume.crosses(before, after))
            return;
        // A fast wheel must not stack sounds
        const now = Date.now();
        if (now - _last < 45)
            return;
        let started = false;
        Volume.tickSinks(nodes.map(n => n ? n.name : "")).forEach((name, i) => {
            const process = players.objectAt(i);
            if (!process || process.running)
                return;
            process.command = [tick.player, "--target", name, "--", tick.path];
            process.running = true;
            started = true;
        });
        if (started)
            _last = now;
    }

    // One player per output a tick can reach, idle until it is asked
    Instantiator {
        id: players
        model: Volume.MAX_TICKS
        delegate: Process {}
    }
}
