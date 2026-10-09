import QtQuick
import Quickshell.Services.Pipewire
import "Target.js" as Target

// Watches the own level of one member of a Listen together group for a change
// nobody asked Orbit for: the headset's buttons (NAK-174). PipeWire already
// reports every change of a node's volume, so this adds no timer and no
// process. What Orbit and the PC keys write themselves is told apart through
// `book` (Target.fromHeadset), and the first read of a node (the group
// starting, the headset connecting) is only the starting point.
Item {
    id: watch

    required property string address
    // The member's own level node (AudioRoute.ownNode), or null
    property var node: null
    // The levels Orbit wrote lately (AudioRoute), to tell its echo apart
    property var book: ({})

    // The headset moved this member's level
    signal heard(string address)

    readonly property var _audio: node && node.ready && node.audio ? node.audio : null
    // The level last read; NaN until the node is ready
    property real _seen: NaN

    on_AudioChanged: _seen = _audio ? _audio.volume : NaN
    Component.onCompleted: _seen = _audio ? _audio.volume : NaN

    PwObjectTracker {
        objects: watch.node ? [watch.node] : []
    }

    Connections {
        target: watch._audio
        function onVolumeChanged() {
            const level = watch._audio.volume;
            const moved = Target.fromHeadset(watch.book, watch.node.name, watch._seen, level, Date.now());
            watch._seen = level;
            if (moved)
                watch.heard(watch.address);
        }
    }
}
