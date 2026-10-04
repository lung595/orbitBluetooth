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

    // Addresses followed; the model below follows it one headset at a time, a
    // new list would rebuild every WearHeadset and lose what it holds
    property var _addresses: []
    // address -> WearHeadset, for the status command
    property var _headsets: ({})

    ListModel {
        id: followed
    }

    function _refresh() {
        const next = Wear.followed(active, ancService.snapshots);
        if (next.join() === _addresses.join())
            return;
        const change = Wear.changes(_addresses, next);
        for (let i = followed.count - 1; i >= 0; i--)
            if (change.removed.indexOf(followed.get(i).address) >= 0)
                followed.remove(i);
        change.added.forEach(address => followed.append({
                "address": address
            }));
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
        model: followed

        delegate: WearHeadset {
            wearing: root.ancService.snapshots[address]?.state?.wearing ?? null
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
