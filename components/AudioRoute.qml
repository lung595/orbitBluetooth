import QtQuick
import QtQml
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "Route.js" as Route

// The two volumes of a Bluetooth audio device (D249): the device's own
// level, and this PC's level, what the PC sends to it. One RouteDevice per
// Bluetooth device does the work; this keeps the list and answers "which
// level does this change?".
Item {
    id: root

    property var prefs: null
    // Called with address -> { sink, pc, absolute } whenever it changes
    property var publish: function (map) {}

    // address -> RouteDevice
    property var _devices: ({})

    // The default output, to set this PC's level without a Bluetooth device
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    Instantiator {
        model: Bluetooth.devices

        delegate: RouteDevice {
            required property var modelData
            device: modelData
            separate: root.prefs ? root.prefs.separatePc : true
            levels: root.prefs ? root.prefs.pcLevels : ({})
            saveLevel: (address, level) => root._saveLevel(address, level)
            onChanged: root._refresh()
        }

        onObjectAdded: (index, object) => {
            const next = Object.assign({}, root._devices);
            next[object.address] = object;
            root._devices = next;
            root._refresh();
        }
        onObjectRemoved: (index, object) => {
            const next = Object.assign({}, root._devices);
            delete next[object.address];
            root._devices = next;
            root._refresh();
        }
    }

    function _saveLevel(address, level) {
        if (!prefs || prefs.pcLevels[address] === level)
            return;
        const next = Object.assign({}, prefs.pcLevels);
        next[address] = level;
        prefs.set("pcLevels", next);
    }

    function _refresh() {
        const map = {};
        for (const a in _devices) {
            const d = _devices[a];
            if (d.sink)
                map[a] = {
                    "sink": d.sink.name,
                    "pc": d.pc ? d.pc.name : "",
                    "absolute": d.absolute
                };
        }
        publish(map);
    }

    // Connected devices that play sound, the one in use first
    function audioDevices() {
        const list = [];
        for (const a in _devices)
            if (_devices[a].sink)
                list.push(_devices[a]);
        const def = Pipewire.defaultAudioSink;
        list.sort((x, y) => ((y.sink === def || y.pc === def) ? 1 : 0) - ((x.sink === def || x.pc === def) ? 1 : 0));
        return list;
    }

    // The Bluetooth device that is the current output (itself or its
    // virtual sink), or null: the pop-up then shows this PC's level only
    readonly property var current: {
        const def = Pipewire.defaultAudioSink;
        for (const a in _devices) {
            const d = _devices[a];
            if (d.sink && def && (d.sink === def || d.pc === def))
                return d;
        }
        return null;
    }

    function find(address) {
        if (address)
            return _devices[address] && _devices[address].sink ? _devices[address] : null;
        return current || audioDevices()[0] || null;
    }

    // The node holding the device's own level, or null when the device
    // follows this PC (no absolute volume)
    function deviceNode(dev) {
        return dev && dev.absolute === 1 ? dev.sink : null;
    }

    // The node holding this PC's level: the virtual sink; the device's sink
    // when the device follows this PC; the default output with no device
    function pcNode(dev) {
        if (!dev)
            return Pipewire.defaultAudioSink;
        if (dev.pc)
            return dev.pc;
        return dev.absolute === 1 ? null : dev.sink;
    }

    // Sets a level from `dms ipc call orbitBluetooth deviceVolume|pcVolume`;
    // returns "" or why it could not
    function setLevel(which, arg, address) {
        const dev = find(address || "");
        const node = which === "device" ? deviceNode(dev) : pcNode(dev);
        if (!node || !node.audio)
            return which === "device" ? (dev ? "no-own-volume" : "no-device") : "no-pc-level";
        const level = Route.ipcLevel(arg, node.audio.volume);
        if (level < 0)
            return "bad-level";
        node.audio.muted = false;
        node.audio.volume = level;
        return "";
    }

    // Clicking the planet (D251): one audio device mutes this PC, several
    // mute that device
    function toggleMute(address) {
        const dev = find(address || "");
        const target = Route.muteTarget(audioDevices().length);
        const node = target === "device" && dev ? dev.sink : pcNode(dev);
        if (node && node.audio)
            node.audio.muted = !node.audio.muted;
        return target;
    }
}
