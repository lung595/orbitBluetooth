pragma ComponentBehavior: Bound
import QtQuick
import "Wear.js" as Wear

// Pause the music when a Sony headset is taken off, resume it when it is put
// back (D277). Follows the headsets whose noise-control session reports a
// wearing sensor (AncService keeps that session open); one WearHeadset per
// such headset does the work, and nothing exists while none is followed.
Item {
    id: root

    required property var ancService
    // The setting (not `enabled`: that is Item's own)
    property bool active: true

    // Addresses followed, replaced only when the set changes: a new list
    // would rebuild every WearHeadset and lose what it holds
    property var _addresses: []
    // address -> WearHeadset, for the status command
    property var _headsets: ({})

    function _refresh() {
        const next = Wear.followed(active, ancService.snapshots);
        if (next.join() !== _addresses.join())
            _addresses = next;
    }
    onActiveChanged: _refresh()
    Component.onCompleted: _refresh()

    Connections {
        target: root.ancService
        function onSnapshotsChanged() {
            root._refresh();
        }
    }

    Instantiator {
        model: root._addresses

        delegate: WearHeadset {
            required property string modelData
            address: modelData
            wearing: root.ancService.snapshots[modelData]?.state?.wearing ?? null
        }

        onObjectAdded: (index, object) => {
            const headset = object as WearHeadset;
            root._headsets = Object.assign({}, root._headsets, {
                [headset.address]: headset
            });
        }
        onObjectRemoved: (index, object) => {
            const next = Object.assign({}, root._headsets);
            delete next[(object as WearHeadset).address];
            root._headsets = next;
        }
    }

    // What `wearStatus` tells about a headset (see Wear.report)
    function statusOf(address) {
        const headset = _headsets[address];
        const device = ancService.deviceFor(address);
        return Wear.report(active, ancService.familyFor(device), ancService.snapshots[address], headset ? headset.held.length : 0);
    }
}
