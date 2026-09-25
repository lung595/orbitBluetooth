import QtQuick
import QtQml
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Services
import "components"
import "components/Anc.js" as Anc

// Event-driven bookkeeping shared by every surface. BlueZ exposes neither a
// connection timestamp, a charging state nor a discharge rate, so we record
// them ourselves and merge what UPower knows.
// No timers: everything reacts to D-Bus property changes. The only process
// is the noise-control helper (see AncService), and only while a supported
// headset is connected and being controlled.
// Privacy: all data stays in memory for the current session; nothing is
// written to disk or sent anywhere.
Item {
    id: root

    property var pluginService: null
    property string pluginId: "orbitBluetooth"

    // address -> epoch ms of the current connection start
    property var since: ({})
    // address -> [[epochMs, percent], ...] for the current connection
    property var batteryLog: ({})
    // address -> { state, percentage, timeToFull, timeToEmpty, changeRate, health }
    property var power: ({})

    readonly property int maxSamples: 64

    // Noise control (ANC) for headphones: address -> helper snapshot
    Prefs {
        id: prefs
    }

    readonly property alias anc: ancService

    AncService {
        id: ancService
        enabled: prefs.ancEnabled
        engine: prefs.ancEngine
        publish: map => root._publish("anc", map)
    }

    // dms ipc call orbitBluetooth anc nc | ambient | off | adaptive
    IpcHandler {
        target: "orbitBluetooth"

        function anc(mode: string): string {
            const address = ancService.primary();
            if (!address)
                return "No supported headset connected";
            if (Anc.ORDER.indexOf(mode) < 0)
                return "Modes: " + Anc.ORDER.join(", ");
            ancService.send(address, "mode", mode);
            return "OK";
        }

        // Next mode on the first connected headset (off is skipped when possible)
        function ancCycle(): string {
            const address = ancService.primary();
            if (!address)
                return "No supported headset connected";
            ancService.cycle(address);
            return "OK";
        }

        function ancStatus(): string {
            const address = ancService.primary();
            const s = ancService.states[address];
            if (!address)
                return "No supported headset connected";
            if (!s || !s.state)
                return "Unknown (open the headset card once, or use the always-connected engine)";
            return JSON.stringify(s.state);
        }
    }

    function _publish(name, value) {
        PluginService.setGlobalVar(pluginId, name, value);
    }

    function onConnection(device, connected) {
        const addr = device.address;
        const next = Object.assign({}, since);
        const log = Object.assign({}, batteryLog);
        if (connected) {
            next[addr] = Date.now();
            log[addr] = [];
        } else {
            delete next[addr];
            delete log[addr];
        }
        since = next;
        batteryLog = log;
        _publish("since", since);
        _publish("batteryLog", batteryLog);
    }

    function onBattery(device, percent) {
        if (percent < 0 || !device.connected)
            return;
        const addr = device.address;
        const samples = (batteryLog[addr] || []).slice(-(maxSamples - 1));
        const last = samples.length ? samples[samples.length - 1][1] : -1;
        if (last === percent)
            return;
        samples.push([Date.now(), percent]);
        const log = Object.assign({}, batteryLog);
        log[addr] = samples;
        batteryLog = log;
        _publish("batteryLog", batteryLog);
    }

    function setPower(addr, info) {
        const next = Object.assign({}, power);
        if (info)
            next[addr] = info;
        else
            delete next[addr];
        power = next;
        _publish("power", power);
    }

    function _macFromText(text) {
        const m = /([0-9a-f]{2}([:_-])[0-9a-f]{2}(\2[0-9a-f]{2}){4})/i.exec(text || "");
        return m ? m[1].replace(/[_-]/g, ":").toUpperCase() : "";
    }

    // UPower devices that belong to a Bluetooth peripheral. BlueZ-backed ones
    // carry the address in their native path; kernel HID batteries (game
    // controllers, Logitech, ...) expose it as HID_UNIQ in sysfs, read once.
    Instantiator {
        model: UPower.devices

        delegate: QtObject {
            id: up
            required property var modelData
            readonly property string nativePath: modelData?.nativePath ?? ""
            readonly property bool fromBluez: nativePath.startsWith("/org/bluez/")
            property string address: fromBluez ? root._macFromText(nativePath) : ""

            readonly property var info: address && !modelData.isLaptopBattery ? {
                "state": modelData.state,
                "percentage": modelData.percentage > 0 ? Math.round(modelData.percentage * 100) : -1,
                "timeToFull": modelData.timeToFull,
                "timeToEmpty": modelData.timeToEmpty,
                "changeRate": Math.abs(modelData.changeRate),
                "health": modelData.healthSupported ? modelData.healthPercentage : -1
            } : null

            onInfoChanged: if (address)
                root.setPower(address, info)
            onAddressChanged: if (address)
                root.setPower(address, info)
            Component.onDestruction: if (address)
                root.setPower(address, null)

            property FileView uevent: FileView {
                path: !up.fromBluez && up.nativePath && !up.nativePath.includes("/") ? "/sys/class/power_supply/" + up.nativePath + "/device/uevent" : ""
                printErrors: false
                onLoaded: {
                    const m = /^HID_UNIQ=(.*)$/m.exec(text());
                    up.address = m ? root._macFromText(m[1]) : "";
                }
            }
        }
    }

    Instantiator {
        model: Bluetooth.devices

        delegate: QtObject {
            required property var modelData
            readonly property bool connected: modelData?.connected ?? false
            // BlueZ battery, or the kernel/UPower one for HID-only devices
            readonly property int percent: modelData?.batteryAvailable ? Math.round(modelData.battery * 100) : (root.power[modelData?.address]?.percentage ?? -1)

            onConnectedChanged: root.onConnection(modelData, connected)
            onPercentChanged: root.onBattery(modelData, percent)

            Component.onCompleted: {
                if (connected)
                    root.onConnection(modelData, true);
                root.onBattery(modelData, percent);
            }
        }
    }
}
