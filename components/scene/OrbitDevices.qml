import QtQuick
import "../device/DeviceCatalog.js" as Catalog
import "Orbit.js" as Orbit

// The devices the orbit shows, one model entry per body: BlueZ's list (plus
// the previews' fake devices) picked by Orbit.pick, then diffed in so the
// existing bodies keep their physics state. A device that goes away keeps
// its entry, marked as leaving, until its body has faded out.
Item {
    id: devices
    required property var scene
    readonly property alias model: bodyModel
    // address -> device for every body, leaving ones included
    property var deviceMap: ({})
    property bool anyConnected: false

    // The devices just picked, best first
    signal listed(var list)

    ListModel {
        id: bodyModel
    }

    function refresh() {
        const s = devices.scene;
        const a = s.adapter;
        const all = (a && a.devices ? a.devices.values : []).concat(s.previewDevices);
        const list = Orbit.pick(all, {
            "isHidden": address => s.prefs.isHidden(address),
            "isUnnamed": Catalog.isUnnamed,
            "showUnnamed": s.prefs.showUnnamed,
            "maxDevices": s.prefs.maxDevices
        });
        const shown = {};
        if (s.btOn) {
            for (const d of list)
                shown[d.address] = d;
        }
        anyConnected = s.btOn && list.some(d => d.connected);

        const entries = [];
        for (let i = 0; i < bodyModel.count; i++) {
            const e = bodyModel.get(i);
            entries.push({
                "address": e.address,
                "leaving": e.leaving
            });
        }
        const next = Orbit.plan(entries, shown, deviceMap);
        for (const [i, leaving] of next.marks)
            bodyModel.setProperty(i, "leaving", leaving);
        for (const address of next.added)
            bodyModel.append({
                "address": address,
                "leaving": false
            });
        deviceMap = next.devices;
        listed(list);
        s.wake();
    }

    // A leaving body has faded out: its entry can go
    function finalizeRemoval(address) {
        for (let i = 0; i < bodyModel.count; i++) {
            const e = bodyModel.get(i);
            if (e.address === address && e.leaving) {
                if (devices.scene.focusBody && devices.scene.focusBody.address === address)
                    devices.scene.clearFocus();
                bodyModel.remove(i);
                return;
            }
        }
    }

    Connections {
        target: devices.scene.adapter?.devices ?? null
        function onValuesChanged() {
            devices.refresh();
            Qt.callLater(devices.scene.ancSyncViews);
        }
    }
    Connections {
        target: devices.scene.prefs
        function onShowUnnamedChanged() {
            devices.refresh();
        }
        function onMaxDevicesChanged() {
            devices.refresh();
        }
        function onHiddenDevicesChanged() {
            devices.refresh();
        }
    }

    // Membership/RSSI changes are not all signalled by the model; a slow poll
    // while someone is looking (or discovery runs) catches the stragglers.
    Timer {
        interval: 1500
        repeat: true
        running: devices.scene.active && devices.scene.btOn && (devices.scene.awake || devices.scene.discovering)
        onTriggered: {
            devices.refresh();
            devices.scene.ancSyncViews();
        }
    }
}
