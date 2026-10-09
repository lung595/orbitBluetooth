import QtQuick
import Quickshell.Services.Pipewire
import "Target.js" as Target

// Watches one level (a group member's, or outside a group a device's own or
// this PC's) for a change nobody asked Orbit for: the headset's buttons
// (NAK-174), or anything else on the PC (NAK-196). PipeWire already
// reports every change of a node's volume, so this adds no timer and no
// process. What Orbit and the PC keys write themselves is told apart through
// `book` (Target.fromHeadset), and the first read of a node (the group
// starting, the headset connecting) is only the starting point.
Item {
    id: watch

    required property string address
    // The member's own level node (AudioRoute.ownNode), or null
    required property var node
    // The levels Orbit wrote lately (AudioRoute), to tell its echo apart
    property var book: ({})
    // Outside a group: a change this soon after the node appears is its own
    // starting level, not a choice (Target.settled); 0 in a group
    property int settleMs: 0

    // The headset moved this member's level
    signal heard(string address)

    readonly property var _audio: node && node.ready && node.audio ? node.audio : null
    // The level last read; NaN until the node is ready
    property real _seen: NaN
    // When it was first read
    property double _readyAt: 0

    on_AudioChanged: _start()
    Component.onCompleted: _start()
    function _start() {
        _seen = _audio ? _audio.volume : NaN;
        _readyAt = Date.now();
    }

    PwObjectTracker {
        objects: watch.node ? [watch.node] : []
    }

    Connections {
        target: watch._audio
        function onVolumeChanged() {
            const level = watch._audio.volume;
            const now = Date.now();
            const moved = Target.fromHeadset(watch.book, watch.node.name, watch._seen, level, now) && Target.settled(watch._readyAt, now, watch.settleMs);
            watch._seen = level;
            if (moved)
                watch.heard(watch.address);
        }
    }
}
