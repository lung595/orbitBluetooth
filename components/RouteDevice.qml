import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Route.js" as Route

// One Bluetooth device, as AudioRoute sees it. When its sound output shows
// up, finds out whether the device has a volume of its own (absolute
// volume): if so, and "Separate PC volume" is on, this PC's level moves to
// a virtual sink in front of the device (D255) and becomes the default
// output, so DMS's slider sets this PC's level.
// Processes: two busctl calls when the sound output appears, one pactl call
// when the virtual sink is made or removed. Nothing runs otherwise.
Item {
    id: dev

    required property var device
    // "Separate PC volume" setting
    property bool separate: true
    // False until AudioRoute has removed what a crashed shell left behind
    property bool ready: false
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
    property string module: ""
    readonly property bool wanted: ready && separate && absolute === 1 && !!sink

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
    onWantedChanged: _sync()
    onModuleChanged: _sync()

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
    function _sync() {
        if (wanted && !module && !loader.running) {
            const args = Route.loadArgs(address, sink.name, name);
            if (!args)
                return;
            loader.command = args;
            loader.running = true;
        } else if (!wanted && module && !unloader.running) {
            // Hand the default output back to the device itself first
            if (sink && Pipewire.defaultAudioSink === pc)
                Pipewire.preferredDefaultAudioSink = sink;
            // A module index is digits only (Route.moduleIndex)
            unloader.command = ["pactl", "unload-module", module];
            unloader.running = true;
        }
    }

    Process {
        id: loader
        stdout: StdioCollector {
            id: loaderOut
        }
        onExited: code => {
            dev.module = code === 0 ? Route.moduleIndex(loaderOut.text) : "";
            if (!dev.module)
                console.warn("Orbit: could not make the virtual sink for this PC's level");
        }
    }

    Process {
        id: unloader
        onExited: dev.module = ""
    }

    // Once the virtual sink is ready: this PC's saved level, then the
    // default output if the device was it
    readonly property bool pcReady: !!pc && !!pc.audio && pc.ready
    onPcReadyChanged: {
        if (!pcReady)
            return;
        const saved = levels[address];
        pc.audio.volume = typeof saved === "number" ? Math.max(0, Math.min(1, saved)) : 1;
        _claimDefault();
    }
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            dev._claimDefault();
        }
    }
    // Picking the device itself in DMS's output list lands on its virtual
    // sink: the two are one device to the user
    function _claimDefault() {
        if (pcReady && sink && Pipewire.defaultAudioSink === sink)
            Pipewire.preferredDefaultAudioSink = pc;
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

    // The shell stops or the plugin reloads: leave PipeWire as it was
    Component.onDestruction: {
        if (!module)
            return;
        const back = sink && Pipewire.defaultAudioSink === pc ? sink.name : "";
        // Data only as positional parameters, never inside the script (value
        // 11); pactl has no "--", but both were checked (Route.js)
        Quickshell.execDetached(["sh", "-c", '[ -n "$1" ] && pactl set-default-sink "$1"; pactl unload-module "$2"', "sh", back, module]);
    }
}
