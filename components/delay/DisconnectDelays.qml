import QtQuick
import Quickshell.Bluetooth
import qs.Services
import "DisconnectPhrase.js" as Phrase

// "Disconnect this device after a delay" (ON7, D423). Orbit counts the delay
// itself: one single-shot Timer per pending delay and nothing else, so at rest
// (no delay pending) nothing runs. Pending delays live in memory only: they die
// with the shell and are never written to disk (value 12).
Item {
    id: root

    // address -> end time in ms since the epoch
    property var pending: ({})
    // Hands the map to the surfaces (the daemon's PluginService global)
    property var publish: map => {}

    // Sands is installed: read from the plugin list, no file written, so the
    // hourglass mark can show only then
    readonly property bool sandsInstalled: PluginService.availablePlugins !== undefined && PluginService.availablePlugins["smartTimer"] !== undefined

    function endOf(address) {
        return pending[address] || 0;
    }

    function _device(address) {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].address === address)
                return list[i];
        }
        return null;
    }

    function _set(next) {
        pending = next;
        publish(next);
    }

    // The devices a phrase or a command may mean: the connected ones only,
    // there is nothing to disconnect on the others
    function _connected() {
        const out = [];
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                out.push({
                    "address": list[i].address,
                    "name": list[i].name || ""
                });
        }
        return out;
    }

    // { ok: true, address, minutes } or { ok: false, why }; why: bad | empty |
    // none | ambiguous. `device` is a name fragment or a Bluetooth address.
    function start(device, minutes) {
        const m = Phrase.cleanMinutes(minutes);
        if (m === null)
            return {
                "ok": false,
                "why": "bad"
            };
        const found = Phrase.findDevice(device, _connected());
        if (!found.ok)
            return found;
        _set(Phrase.schedule(pending, found.address, m, Date.now()));
        return {
            "ok": true,
            "address": found.address,
            "minutes": m
        };
    }

    function stop(device) {
        const found = Phrase.findDevice(device, _connected());
        if (!found.ok)
            return found;
        if (pending[found.address] === undefined)
            return {
                "ok": false,
                "why": "nothing"
            };
        _set(Phrase.cancel(pending, found.address));
        return {
            "ok": true,
            "address": found.address
        };
    }

    // A delay ran out: the device goes unless it left by itself meanwhile
    function _expire(address) {
        const device = _device(address);
        _set(Phrase.cancel(pending, address));
        if (device && device.connected)
            device.disconnect();
    }

    // One single-shot timer per pending delay. The interval is what is left
    // until the end time, so rebuilding the delegates never stretches a delay.
    Instantiator {
        model: Object.keys(root.pending)
        delegate: Timer {
            required property string modelData
            interval: Math.max(1, root.endOf(modelData) - Date.now())
            repeat: false
            running: true
            onTriggered: root._expire(modelData)
        }
    }

    // A device that disconnects by itself drops its delay
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (!modelData.connected && root.pending[modelData.address] !== undefined)
                    root._set(Phrase.cancel(root.pending, modelData.address));
            }
        }
    }
}
