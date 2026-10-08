import QtQuick
import Quickshell.Services.Pipewire

// Whether sound is flowing into the source's output, so that the beams pulse
// only while something plays. Event-driven (PipeWire says when a link starts
// or stops running); it is loaded only while the group is wanted, the scene
// is awake and Reduce motion is off, so it costs nothing otherwise.
// Best effort: a link that PipeWire keeps "active" without sound reads as
// playing, which only means the pulses keep going.
Item {
    id: watch

    // The node whose links are watched: the source's output (the PC level)
    required property var node
    readonly property bool playing: Array.from(tracker.linkGroups).some(g => g.state === PwLinkState.Active)

    PwNodeLinkTracker {
        id: tracker
        node: watch.node
    }
    // A link group only tells its state once it is bound
    PwObjectTracker {
        objects: Array.from(tracker.linkGroups)
    }
}
