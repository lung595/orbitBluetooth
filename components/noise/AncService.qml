import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Common
import "Anc.js" as Anc
import "AncSnapshot.js" as Snapshot
import "../wear/Wear.js" as Wear

// Runs the Python helper (anc/orbit_anc.py) that speaks each headset's
// vendor protocol, and publishes what it reports to every surface.
//
// Two engines, chosen in the settings:
// - "demand" (default): a session exists only while an Orbit view showing
//   the headset is open, or for the second it takes to apply a command.
// - "live": one session per connected supported headset, so changes made
//   with the headset's own buttons show up immediately.
// - Wear pause (setting, Sony headsets that report wearing): the session
//   also stays open while the headset is connected, whatever the engine,
//   so that taking it off is noticed at once (see components/wear/).
// Nothing runs while no supported headset is connected.
Item {
    id: root

    property bool active: true
    property string engine: "demand"
    // Called with the address -> snapshot map whenever it changes
    property var publish: function (map) {}

    // Conversation awareness has no off switch once the headset is gone: a
    // disconnected headset keeps it, and only Orbit could turn it off. With
    // this on, it is switched off before Orbit disconnects a headset, and
    // again right after any reconnection (headset switched off, out of range
    // or disconnected elsewhere). The noise-control mode is never touched.
    property bool chatOffOnDisconnect: true

    // Keep a session open for the wearing sensor of Sony headsets. Costs one
    // open control connection per such headset, nothing else (no polling):
    // the headset reports by itself
    property bool wearPause: false

    // address -> last snapshot {status, error, model, features, state, live}
    property var snapshots: ({})
    // address -> number of open detail cards showing it
    property var _viewers: ({})
    // address -> Process
    property var _sessions: ({})
    // address -> commands sent while a session was closing, replayed after it
    property var _queue: ({})
    // address -> true while a disconnect waits for conversation awareness to go off
    property var _leaving: ({})
    // Addresses connected a moment ago, whose vendor channel is still settling
    property var _reconnected: []

    readonly property string _helper: Paths.strip(Qt.resolvedUrl("../../anc/orbit_anc.py"))

    function deviceFor(address) {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].address === address)
                return list[i];
        return null;
    }

    function familyFor(device) {
        return device ? Anc.family(device.deviceName || device.name || "") : "";
    }

    // Only paired, connected headsets: opening a vendor channel to an
    // unpaired device makes BlueZ bring up a temporary link on its own,
    // which then drops again (seen with FreeBuds that were never paired)
    function supported(address) {
        const d = deviceFor(address);
        return active && !!d && d.connected && (d.paired || d.bonded) && familyFor(d) !== "";
    }

    function _setState(address, value) {
        snapshots = Snapshot.put(snapshots, address, value || null);
        publish(snapshots);
    }

    // Keep a session only while it is wanted by the engine, a viewer or the
    // wearing sensor (not while the link settles, nor while it is leaving)
    function _wanted(address) {
        if (!supported(address) || _leaving[address])
            return false;
        return engine === "live" || (_viewers[address] || 0) > 0 || (_reconnected.indexOf(address) < 0 && Wear.sessionWanted(wearPause, familyFor(deviceFor(address)), snapshots[address]));
    }

    function _open(address) {
        if (_sessions[address] || !supported(address))
            return _sessions[address] || null;
        const proc = sessionComponent.createObject(root, {
            "address": address,
            // -E -s: ignore PYTHON* variables and user packages. The name
            // goes through the environment: argv is readable by every user
            // in /proc, and a device name can be a person's name
            "command": ["python3", "-E", "-s", _helper, address, familyFor(deviceFor(address))],
            "environment": {
                "ORBIT_ANC_NAME": deviceFor(address).deviceName || deviceFor(address).name || ""
            }
        });
        _sessions = Snapshot.put(_sessions, address, proc);
        // The helper starts the reports once the headset has said it can
        if (Wear.eligible(wearPause, familyFor(deviceFor(address))))
            proc.write("set wear on\n");
        return proc;
    }

    // Closing stdin lets the helper finish pending commands, then exit
    function _release(address) {
        const proc = _sessions[address];
        if (proc && !_wanted(address))
            proc.stdinEnabled = false;
    }

    function _sync(address) {
        if (_wanted(address))
            _open(address);
        else
            _release(address);
    }

    function _syncAll() {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++)
            _sync(list[i].address);
    }

    function watch(address, on) {
        const count = Math.max(0, (_viewers[address] || 0) + (on ? 1 : -1));
        _viewers = Snapshot.put(_viewers, address, count || null);
        _sync(address);
    }

    function send(address, key, value) {
        if (!supported(address))
            return false;
        const line = "set " + key + " " + value + "\n";
        const proc = _open(address);
        if (!proc)
            return false;
        if (proc.stdinEnabled) {
            proc.write(line);
        } else {
            // Only one connection per headset: wait for the closing one
            _queue = Snapshot.put(_queue, address, (_queue[address] || []).concat([line]));
        }
        const updated = Snapshot.withSetting(snapshots[address], key, value);
        if (updated)
            _setState(address, updated);
        _release(address);
        return true;
    }

    // Disconnects a device on behalf of the user. A headset in conversation
    // mode first gets "chat off" and is disconnected once the helper has
    // finished (it exits when the headset confirmed), or after a short
    // timeout if the headset stays silent.
    function disconnectDevice(address) {
        const device = deviceFor(address);
        if (!device)
            return;
        const known = snapshots[address];
        // Known not to have the feature, or known to be off: nothing to undo
        const needless = known && known.features && (!known.features.chat || (known.state && known.state.chat === false));
        if (!chatOffOnDisconnect || needless) {
            device.disconnect();
            return;
        }
        // Marked first: a session that only stays open for the wearing
        // sensor must close once the command is confirmed
        _leaving = Snapshot.put(_leaving, address, true);
        if (send(address, "chat", "off")) {
            leaveTimer.restart();
        } else {
            _leaving = Snapshot.put(_leaving, address, null);
            device.disconnect();
        }
    }

    function _finishLeaving(address) {
        if (!_leaving[address])
            return;
        _leaving = Snapshot.put(_leaving, address, null);
        const device = deviceFor(address);
        if (device && device.connected)
            device.disconnect();
    }

    // The headset never answered: do not keep the user waiting
    Timer {
        id: leaveTimer
        interval: 4000
        onTriggered: Object.keys(root._leaving).forEach(a => root._finishLeaving(a))
    }

    function cycle(address) {
        const s = snapshots[address];
        const next = s && s.features ? Anc.nextMode(s.features.modes, s.state.mode) : "";
        if (next)
            return send(address, "mode", next);
        // Never talked to it yet: ask, then let the user cycle again
        const proc = _open(address);
        _release(address);
        return !!proc;
    }

    // First connected headset that can be controlled (for IPC), of the
    // given brand family when one is asked for
    function primary(family) {
        const list = Bluetooth.devices.values;
        for (let i = 0; i < list.length; i++)
            if (list[i].connected && familyFor(list[i]) && (!family || familyFor(list[i]) === family))
                return list[i].address;
        return "";
    }

    // The vendor channel is not ready the instant BlueZ reports the link, and
    // the pairing/audio setup is still busy: wait a little before talking
    function _chatOffLater(address) {
        if ((!chatOffOnDisconnect && !wearPause) || _reconnected.indexOf(address) >= 0)
            return;
        _reconnected = _reconnected.concat([address]);
        reconnectTimer.restart();
    }

    Timer {
        id: reconnectTimer
        interval: 2500
        onTriggered: {
            const list = root._reconnected;
            root._reconnected = [];
            // The helper applies it once the handshake is done and the
            // headset has announced the feature (nothing happens without
            // it), then closes again
            list.forEach(a => {
                if (root.chatOffOnDisconnect && root.supported(a))
                    root.send(a, "chat", "off");
                else
                    root._sync(a);
            });
        }
    }

    function _onLine(proc, line) {
        const address = proc.address;
        // A line from a headset that just left (its error, typically) must
        // not bring back the state its disconnection cleared: an error
        // snapshot would keep every session closed after it reconnects
        if (!deviceFor(address)?.connected)
            return;
        const next = Snapshot.merge(snapshots[address], line, (_queue[address] || []).length > 0, Date.now());
        if (!next)
            return;
        proc.reached = proc.reached || next.status === "ready";
        _setState(address, next);
        // A session kept only to look for the wearing sensor ends as soon
        // as the headset shows it has none
        _release(address);
    }

    function _onExit(proc) {
        const address = proc.address;
        if (_sessions[address] === proc)
            _sessions = Snapshot.put(_sessions, address, null);
        const prev = snapshots[address];
        if (prev)
            _setState(address, Object.assign({}, prev, {
                "live": false
            }));
        proc.destroy();
        const leaving = !!_leaving[address];
        _finishLeaving(address);
        const queued = _queue[address] || [];
        _queue = Snapshot.put(_queue, address, null);
        // After an error, stay quiet until the user asks again (no retry loop)
        if (prev && prev.status === "error")
            return;
        if (queued.length && !leaving) {
            const again = _open(address);
            if (again)
                queued.forEach(l => again.write(l));
        }
        // Reopen by itself only after a session that got as far as a ready
        // headset: a helper that cannot even start must not loop
        if (proc.reached && !leaving)
            _sync(address);
    }

    onEngineChanged: Object.keys(Object.assign({}, _viewers, _sessions)).forEach(_sync)
    onActiveChanged: _syncAll()

    // Tells the sessions already open; the others open or close by the rules above
    onWearPauseChanged: {
        for (const a in _sessions)
            if (_sessions[a].stdinEnabled && Wear.eligible(true, familyFor(deviceFor(a))))
                _sessions[a].write("set wear " + (wearPause ? "on" : "off") + "\n");
        _syncAll();
    }

    Component {
        id: sessionComponent

        Process {
            id: proc
            property string address: ""
            // Whether the headset ever answered as ready in this session
            property bool reached: false
            running: true
            stdinEnabled: true
            stdout: SplitParser {
                onRead: data => root._onLine(proc, data)
            }
            onExited: root._onExit(proc)
        }
    }

    // Follow connections: start live sessions, forget state on disconnect
    Instantiator {
        model: Bluetooth.devices

        delegate: QtObject {
            required property var modelData
            readonly property bool connected: modelData?.connected ?? false

            onConnectedChanged: {
                if (!connected)
                    root._setState(modelData.address, null);
                else
                    root._chatOffLater(modelData.address);
                root._sync(modelData.address);
            }
            Component.onCompleted: if (connected)
                root._sync(modelData.address)
        }
    }

    Component.onDestruction: Object.keys(_sessions).forEach(a => _sessions[a].running = false)
}
