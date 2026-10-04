import QtQuick
import Quickshell.Services.Pipewire
import "Radio.js" as Radio

// The pair of Bluetooth outputs playing at the same time (Radio.sharedKey),
// "" while fewer than two do. Event-driven: PipeWire says when a link starts
// or stops running. Loaded only while two outputs of the adapter exist
// (OrbitRadio), so it costs nothing with one headset.
// Best effort, like the centre's beams (CentreWatch): a link PipeWire keeps
// "active" without sound reads as playing.
Item {
    id: watch

    // Address -> device, the adapter's own devices
    required property var known

    readonly property var _groups: Array.from(Pipewire.linkGroups.values)
    readonly property string key: Radio.sharedKey(_groups.map(g => ({
                "sink": g.target ? g.target.name : "",
                "active": g.state === PwLinkState.Active
            })), known)

    // A link group only tells its state once it is bound
    PwObjectTracker {
        objects: watch._groups
    }
}
