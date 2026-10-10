import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Services
import "DisconnectPhrase.js" as Phrase

// "Disconnect this device after a delay" (ON7, D423). Orbit counts the delay
// itself: one single-shot Timer per pending delay and nothing else, so at rest
// (no delay pending) nothing runs. Pending delays live in memory only: they die
// with the shell and are never written to disk (value 12).
Scope {
    id: root

    // Hands the map and the Sands flag to the surfaces (the daemon's PluginService global)
    required property var publish

    // address -> end time in ms since the epoch; changed only by this engine
    readonly property var pending: _pending
    property var _pending: ({})

    // Sands is installed: read from the plugin list, no file written, so the
    // hourglass mark can show only then
    readonly property bool sandsInstalled: PluginService.availablePlugins !== undefined && PluginService.availablePlugins["smartTimer"] !== undefined

    // Published at start and whenever it changes, so a surface never reads a
    // stale or missing flag
    onSandsInstalledChanged: _push()
    Component.onCompleted: _push()

    function _push() {
        publish({
            "ends": _pending,
            "sands": sandsInstalled
        });
    }

    function endOf(address) {
        return _pending[address] || 0;
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
        _pending = next;
        _push();
    }

    // { ok: true, address, minutes } or { ok: false, why }; why: badDelay | noDevice |
    // none | ambiguous. `device` is a name fragment or a Bluetooth address.
    function start(device, minutes) {
        const m = Phrase.cleanMinutes(minutes);
        if (m === null)
            return {
                "ok": false,
                "why": "badDelay"
            };
        const found = Phrase.findDevice(device, Phrase.connectedOf(Bluetooth.devices.values));
        if (!found.ok)
            return found;
        _set(Phrase.schedule(_pending, found.address, m, Date.now()));
        return {
            "ok": true,
            "address": found.address,
            "minutes": m
        };
    }

    function stop(device) {
        const found = Phrase.findDevice(device, Phrase.connectedOf(Bluetooth.devices.values));
        if (!found.ok)
            return found;
        if (_pending[found.address] === undefined)
            return {
                "ok": false,
                "why": "nothing"
            };
        _set(Phrase.cancel(_pending, found.address));
        return {
            "ok": true,
            "address": found.address
        };
    }

    // A delay ran out: the device goes unless it left by itself meanwhile
    function _expire(address) {
        const device = _device(address);
        _set(Phrase.cancel(_pending, address));
        if (device && device.connected)
            device.disconnect();
    }

    // One single-shot timer per pending delay, and, for the same delay only, a
    // watch on its device: one that disconnects by itself drops the delay. The
    // interval is what is left until the end time, so rebuilding the delegates
    // never stretches a delay. With nothing pending, nothing exists.
    Instantiator {
        model: Object.keys(root._pending)
        delegate: QtObject {
            id: entry
            required property string modelData
            readonly property Timer timer: Timer {
                interval: Math.max(1, root.endOf(entry.modelData) - Date.now())
                repeat: false
                running: true
                onTriggered: root._expire(entry.modelData)
            }
            readonly property Connections watch: Connections {
                target: root._device(entry.modelData)
                function onConnectedChanged() {
                    if (!target.connected)
                        root._set(Phrase.cancel(root._pending, entry.modelData));
                }
            }
        }
    }
}
