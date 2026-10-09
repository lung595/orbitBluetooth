import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../device/DeviceCatalog.js" as Catalog
import "Offer.js" as Offer
import "Guard.js" as Guard
import "NearestFilter.js" as Nearest

// What the "new device" pop-up may offer next: watches BlueZ's device list
// for a named, unpaired audio device that discovery just found, and keeps
// the ones waiting for their turn. "Later" snoozes an address, so it is not
// offered again for a while. When several PCs run Orbit, the one nearest to
// the device goes first (NearestFilter): the signal is read once when the
// device shows up, the farther PC waits, and the signal is read again when
// the wait ends. No reading means today's behavior: queued at once.
Item {
    id: offers

    required property var prefs
    required property bool offering
    property var adapter: null
    // The screen is awake (a sleeping PC gives way to one in use)
    property bool screenOn: true
    // Recent use of this PC, undefined while Orbit does not know it
    property var recentUse: undefined
    // NearestFilter limits, the defaults when empty
    property var nearestOptions: ({})
    // The address the pop-up shows now (never queued twice)
    property string current: ""

    // Addresses waiting for the pop-up, oldest first
    property var pending: []
    // Something was queued
    signal queued
    // Addresses between "found" and "queued": the signal is being read or the
    // wait for a nearer PC is running
    property var _waiting: []

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
        // Only what discovery just found is in range
        if (!adapter || !adapter.discovering)
            return;
        if (current === address || pending.indexOf(address) >= 0 || _waiting.indexOf(address) >= 0)
            return;
        if (!Offer.offerable(address, _snoozed, Date.now()))
            return;
        _waiting = _waiting.concat([address]);
        reader.read(deviceFor(address), rssi => _decide(address, rssi));
    }

    function _context(rssi) {
        return {
            "rssi": rssi,
            "discovering": !!adapter && adapter.discovering,
            "screenOn": screenOn,
            "recentUse": recentUse,
            "opts": nearestOptions
        };
    }

    // First reading: queue now, or wait for a nearer PC, or drop
    function _decide(address, rssi) {
        const verdict = Nearest.shouldOffer(_context(rssi));
        if (!verdict.offer) {
            _release(address);
        } else if (verdict.delayMs <= 0) {
            _enqueue(address);
        } else {
            wait.createObject(offers, {
                "queue": offers,
                "address": address,
                "interval": verdict.delayMs
            });
        }
    }

    // The wait is over: is the device still worth a pop-up here?
    function _recheck(address) {
        const device = deviceFor(address);
        if (!offering || !isCandidate(device)) {
            _release(address);
            return;
        }
        reader.read(device, rssi => {
            if (Nearest.recheck(_context(rssi)).offer)
                _enqueue(address);
            else
                _release(address);
        });
    }

    function _release(address) {
        _waiting = _waiting.filter(a => a !== address);
    }

    function _enqueue(address) {
        _release(address);
        if (!offering || current === address || pending.indexOf(address) >= 0 || !isCandidate(deviceFor(address)))
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

    SignalRead {
        id: reader
    }

    // One single-shot timer per waiting device, gone once it fired
    Component {
        id: wait

        Timer {
            required property var queue
            required property string address
            running: true
            onTriggered: {
                queue._recheck(address);
                destroy();
            }
        }
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
