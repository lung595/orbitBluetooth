import QtQuick
import Quickshell.Services.Pipewire
import "../volume/Route.js" as Route
import "Wear.js" as Wear

// The applications whose sound reaches one Bluetooth headset right now: the
// streams linked to the headset's output, or to the virtual output that
// carries this PC's level (AudioRoute). `apps` holds one list of names per
// stream, matched against the media players by Wear.js. Only created while
// the headset's wearing is followed, so it costs nothing otherwise; it only
// reacts when a stream starts, stops or is renamed.
Item {
    id: root

    required property string address

    readonly property var _sink: Route.deviceSink(Pipewire.nodes.values, address)
    readonly property var _pc: Route.virtualSink(Pipewire.nodes.values, address)

    PwNodeLinkTracker {
        id: onSink
        node: root._sink
    }
    PwNodeLinkTracker {
        id: onPc
        node: root._pc
    }

    // Streams that play INTO the headset (a link group's source). Orbit's own
    // loopback into the device's sink is one of them; no player carries its name.
    readonly property var _sources: {
        const nodes = [];
        for (const tracker of [onSink, onPc]) {
            const groups = tracker.linkGroups;
            for (let i = 0; i < groups.length; i++)
                if (groups[i].source && groups[i].target && groups[i].target === tracker.node)
                    nodes.push(groups[i].source);
        }
        return nodes;
    }

    // A stream's properties (its application name) arrive once it is bound
    PwObjectTracker {
        objects: root._sources
    }

    readonly property var apps: _sources.map(node => Wear.streamKeys(node.properties))
}
