import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../device/DeviceCatalog.js" as Catalog
import "Offer.js" as Offer
import "Guard.js" as Guard

// What the "new device" pop-up may offer next: watches BlueZ's device list
// for a named, unpaired audio device that discovery just found, and keeps
// the ones waiting for their turn. "Later" snoozes an address, so it is not
// offered again for a while.
Item {
    id: offers

    required property var prefs
    required property bool offering
    property var adapter: null
    // The address the pop-up shows now (never queued twice)
    property string current: ""

    // Addresses waiting for the pop-up, oldest first
    property var pending: []
    // Something was queued
    signal queued

    // address -> epoch ms before which it is not offered again
    property var _snoozed: ({})
    // Devices BlueZ already lists when the shell starts are its cache, not
    // news: they wait out one snooze before they can be offered
    property bool _primed: false

    function deviceFor(address) {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].address === address)
                return list[i];
        return null;
    }

    function isCandidate(d) {
        return !!d && Offer.isCandidate({
            "address": d.address,
            "name": Catalog.deviceName(d),
            "paired": d.paired || d.bonded,
            "connected": d.connected
        }, Guard.offerFamily(d.icon), prefs.ignoredDevices);
    }

    function snooze(address) {
        const next = Object.assign({}, _snoozed);
        next[address] = Date.now() + Offer.snoozeMs;
        _snoozed = next;
    }

    function consider(address) {
        if (!offering)
            return;
        if (!_primed) {
            snooze(address);
            return;
        }
        // Only what discovery just found is in range (Quickshell has no RSSI)
        if (!adapter || !adapter.discovering)
            return;
        if (current === address || pending.indexOf(address) >= 0)
            return;
        if (!Offer.offerable(address, _snoozed, Date.now()))
            return;
        pending = pending.concat([address]);
        queued();
    }

    // The next queued address that is still worth offering ("" when none)
    function take() {
        while (pending.length) {
            const address = pending[0];
            pending = pending.slice(1);
            if (isCandidate(deviceFor(address)))
                return address;
        }
        return "";
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: offers._primed = true
    }

    Instantiator {
        model: Bluetooth.devices

        delegate: QtObject {
            required property var modelData
            // The name often arrives a moment after the device itself
            readonly property bool candidate: offers.offering && offers.isCandidate(modelData)
            onCandidateChanged: if (candidate)
                offers.consider(modelData.address)
            Component.onCompleted: if (candidate)
                offers.consider(modelData.address)
        }
    }
}
