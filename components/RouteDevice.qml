import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Route.js" as Route

// One Bluetooth device, as AudioRoute sees it. When its sound output shows
// up, finds out whether the device has a volume of its own (absolute
// volume): if so, and "Separate PC volume" is on, this PC's level moves to
// a WirePlumber smart filter in front of the device (D255, D259). The
// default output stays the device: DMS's slider and the volume keys set the
// device's own level, Orbit sets this PC's.
// Processes: two busctl calls when the sound output appears, and one
// pw-loopback that lives as long as the filter and dies with the shell.
Item {
    id: dev

    required property var device
    // "Separate PC volume" setting
    property bool separate: true
    // Saved levels of this PC, address -> 0..1 (setting "pcLevels", D256)
    property var levels: ({})
    property var saveLevel: function (address, level) {}

    signal changed

    readonly property string address: device?.address ?? ""
    readonly property string name: device?.deviceName || device?.name || ""
    readonly property bool connected: device?.connected ?? false
    readonly property var sink: connected ? Route.deviceSink(Pipewire.nodes.values, address) : null
    readonly property var pc: Route.virtualSink(Pipewire.nodes.values, address)
    // -1 unknown yet, 0 the device follows this PC's level, 1 it has its own
    property int absolute: -1
    readonly property bool wanted: separate && absolute === 1 && !!sink

    PwObjectTracker {
        objects: [dev.sink, dev.pc].filter(n => !!n)
    }

    onSinkChanged: {
        if (sink && absolute < 0)
            probe();
        if (!sink)
            absolute = -1;
        changed();
    }
    onPcChanged: changed()
    onAbsoluteChanged: changed()

    // --- Does the device have its own volume? --------------------------------
    // BlueZ gives the audio transport a "Volume" property only then (D257)
    property bool _retried: false
    function probe() {
        if (tree.running || !device || !device.dbusPath)
            return;
        tree.running = true;
    }

    Process {
        id: tree
        command: ["busctl", "tree", "--list", "org.bluez"]
        stdout: StdioCollector {
            id: treeOut
        }
        onExited: code => {
            const path = code === 0 && dev.device ? Route.transportPath(treeOut.text, dev.device.dbusPath) : "";
            if (!path) {
                dev._settle(0);
                return;
            }
            volume.command = ["busctl", "--json=short", "get-property", "--", "org.bluez", path, "org.bluez.MediaTransport1", "Volume"];
            volume.running = true;
        }
    }

    Process {
        id: volume
        stdout: StdioCollector {
            id: volumeOut
        }
        onExited: code => dev._settle(code === 0 && Route.transportVolume(volumeOut.text) >= 0 ? 1 : 0)
    }

    // Some devices agree on absolute volume a moment after their sound
    // output appears: one more look, once, a few seconds later
    function _settle(value) {
        absolute = value;
        if (value === 0 && !_retried && sink) {
            _retried = true;
            retry.restart();
        }
    }
    Timer {
        id: retry
        interval: 4000
        onTriggered: if (dev.sink && dev.absolute === 0)
            dev.probe()
    }

    // --- The virtual sink --------------------------------------------------------
    // Stopping the process (wanted turns false, the plugin stops, the shell
    // quits or crashes) removes the filter and WirePlumber links the apps
    // straight to the device again: nothing to undo, nothing left (value 12)
    Process {
        id: filter
        command: dev.sink ? (Route.filterArgs(dev.address, dev.sink.name, dev.name) || []) : []
        running: dev.wanted && command.length > 0
        // The pipe bash watches: it closes when the shell goes away
        stdinEnabled: true
        onExited: code => {
            if (dev.wanted && code !== 0)
                console.warn("Orbit: the filter for this PC's level stopped, code", code);
        }
    }

    // Once the virtual sink is ready: this PC's saved level for this device
    readonly property bool pcReady: !!pc && !!pc.audio && pc.ready
    onPcReadyChanged: {
        if (!pcReady)
            return;
        const saved = levels[address];
        pc.audio.volume = typeof saved === "number" ? Math.max(0, Math.min(1, saved)) : 1;
    }

    // Remember this PC's level for this device, a moment after it settles
    Connections {
        target: dev.pcReady ? dev.pc.audio : null
        function onVolumeChanged() {
            save.restart();
        }
    }
    Timer {
        id: save
        interval: 800
        onTriggered: if (dev.pcReady)
            dev.saveLevel(dev.address, Math.round(dev.pc.audio.volume * 100) / 100)
    }
}
