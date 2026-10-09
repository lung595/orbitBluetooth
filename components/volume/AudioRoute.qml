pragma ComponentBehavior: Bound
import QtQuick
import QtQml
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "Route.js" as Route
import "Steps.js" as Steps
import "Target.js" as Target
import "../together"
import "../together/Member.js" as Member
import "../together/Wired.js" as Wired

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

    // Listen together: two to four outputs, the same sound (D254)
    readonly property alias together: session
    TogetherSession {
        id: session
        route: root
        fineDelayMs: root.prefs ? root.prefs.togetherFineDelay : 0
    }

    // A wired output (D298) by its node name, and the delay filter Orbit runs
    // in front of it while it is a session's source, or null
    function wiredSink(name) {
        return Route.sinkNamed(Pipewire.nodes.values, name);
    }
    function wiredFilter(name) {
        return Route.sinkNamed(Pipewire.nodes.values, Route.wiredFilterName(name));
    }
    // The wired outputs PipeWire lists right now (Wired.fromNodes), read when
    // asked for (the command line) and never watched
    function wiredSinks() {
        return Wired.fromNodes(Pipewire.nodes.values);
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
            onFilterReady: root.together.realign(address)
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

    // A Bluetooth device Orbit sees, with or without a sound output
    function known(address) {
        return _devices[address] || null;
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

    // The tick that lets you hear where a level is, in the outputs it reached
    VolumeTick {
        id: tick
        prefs: root.prefs
    }

    // Orbit is about to move a level. DMS answers a change of level with a
    // sound of its own, which the tick replaces (DmsQuiet, D360): whoever holds
    // it back must be in place before the level moves, so every write below
    // says so first.
    signal levelWriting

    // A level or a mute written to a node reaches every member's copy when
    // it is the PC level of a Listen together session (Route.levelNodes). The
    // tick follows: in that node's output alone, or in every member's when it
    // is the group's level.
    function writeLevel(node, level) {
        levelWriting();
        const before = node.audio.volume;
        Route.writeLevel(together.sharedNodes, node, level);
        tick.play(Route.levelNodes(together.sharedNodes, node), before, level);
    }
    // A level written to each of `nodes` on its own, unmuted: the group's
    // general level when the members keep their own levels (and their gaps),
    // `levels` being what each one gets. Every one of them ticks.
    function writeLevels(nodes, levels, before, after) {
        levelWriting();
        nodes.forEach((n, i) => {
            n.audio.muted = false;
            n.audio.volume = levels[i];
        });
        tick.play(nodes, before, after);
    }
    function writeMuted(node, muted) {
        Route.writeMuted(together.sharedNodes, node, muted);
    }

    // Sets a level from `dms ipc call orbitBluetooth deviceVolume|pcVolume`;
    // returns "" or why it could not. "up" / "down" take a smart step
    function setLevel(which, arg, address) {
        const dev = find(address || "");
        const node = which === "device" ? deviceNode(dev) : pcNode(dev);
        if (!node || !node.audio)
            return which === "device" ? (dev ? "no-own-volume" : "no-device") : "no-pc-level";
        const a = String(arg === undefined || arg === null ? "" : arg).trim().toLowerCase();
        if (a === "up" || a === "down") {
            stepNode(node, a === "up" ? 1 : -1);
            return "";
        }
        const level = Route.ipcLevel(arg, node.audio.volume);
        if (level < 0)
            return "bad-level";
        writeLevel(node, level);
        return "";
    }

    // The level the user hears move first: the device's own when it has
    // one, else this PC's (`dms ipc call orbitBluetooth volume up|down`)
    function mainPart(address) {
        return deviceNode(find(address || "")) ? "device" : "pc";
    }

    // --- Smart steps (D264) ---------------------------------------------------------
    // One state for every caller (keys, wheel): a fast run of presses is one
    // run, wherever it comes from
    property var _stepState: null
    function stepFor(dir, level) {
        if (!prefs || prefs.volumeSteps === "fixed")
            return prefs ? prefs.volumeStep : 5;
        const r = Steps.next(_stepState, Date.now(), dir, prefs.volumeSpeed, level);
        _stepState = r.state;
        return r.step;
    }
    function stepNode(node, dir) {
        const now = node.audio.volume;
        writeLevel(node, Steps.apply(now, dir, stepFor(dir, now)));
    }

    // A member's own level: its Bluetooth device's, or its output's when it is
    // a wired one; null when the device follows this PC and has none
    function ownNode(address) {
        const node = Member.isWired(address) ? wiredSink(address) : deviceNode(known(address));
        return node && node.audio ? node : null;
    }

    // --- The target of the keys (NAK-9) ---------------------------------------------
    // The member whose own level was touched last, in the scope, the radar or
    // a card; "" once the group's level (or none) was. It goes back to the
    // group when the group ends, and when the pop-up closes (TwoLevels).
    property string touched: ""
    function touch(address) {
        if (touched !== address)
            touched = address;
    }
    Connections {
        target: root.together
        function onActiveChanged() {
            if (!root.together.active)
                root.touch("");
        }
    }

    // The volume keys (`dms ipc call orbitBluetooth volume up|down`): the
    // member touched last while a group plays (Target.resolve), else the
    // output you hear, Bluetooth or not. Never another device: with the
    // sound on a wired output, a connected headset must not move (P136)
    function stepHeard(dir) {
        const member = together.active ? Target.resolve(touched, together.members, a => !!ownNode(a)) : "";
        const dev = current;
        const node = member ? ownNode(member) : (deviceNode(dev) || pcNode(dev));
        if (!node || !node.audio)
            return "no-pc-level";
        stepNode(node, dir);
        return "";
    }

    // Clicking the planet (D251): one audio device mutes this PC, several
    // mute that device
    function toggleMute(address) {
        const dev = find(address || "");
        const target = Route.muteTarget(audioDevices().length);
        const node = target === "device" && dev ? dev.sink : pcNode(dev);
        if (node && node.audio)
            writeMuted(node, !node.audio.muted);
        return target;
    }
}
