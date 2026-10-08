import QtQuick
import QtQml
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import "Address.js" as Address

// What BlueZ does not keep, recorded as it happens: when each device
// connected, its battery samples for the current connection, and what UPower
// knows about it (charging state, discharge rate, health). Event-driven, no
// timer. Every change is handed to `publish(name, value)`.
Item {
    id: root

    // Called with the name of a map and the new map
    property var publish: function (name, value) {}

    // address -> epoch ms of the current connection start
    property var since: ({})
    // address -> [[epochMs, percent], ...] for the current connection
    property var batteryLog: ({})
    // address -> { state, percentage, timeToFull, timeToEmpty, changeRate, health }
    property var power: ({})

    readonly property int maxSamples: 64

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
        publish("since", since);
        publish("batteryLog", batteryLog);
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
        publish("batteryLog", batteryLog);
    }

    function setPower(addr, info) {
        const next = Object.assign({}, power);
        if (info)
            next[addr] = info;
        else
            delete next[addr];
        power = next;
        publish("power", power);
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
            property string address: fromBluez ? Address.find(nativePath) : ""

            readonly property var info: address && !modelData.isLaptopBattery ? {
                "state": modelData.state,
                "percentage": modelData.percentage > 0 ? Math.round(modelData.percentage * 100) : -1,
                "timeToFull": modelData.timeToFull,
                "timeToEmpty": modelData.timeToEmpty,
                "changeRate": Math.abs(modelData.changeRate),
                "health": modelData.healthSupported ? modelData.healthPercentage : -1
            } : null

            onInfoChanged: if (up.address)
                root.setPower(up.address, up.info)
            onAddressChanged: if (up.address)
                root.setPower(up.address, up.info)
            Component.onDestruction: if (up.address)
                root.setPower(up.address, null)

            property FileView uevent: FileView {
                path: !up.fromBluez && up.nativePath && !up.nativePath.includes("/") ? "/sys/class/power_supply/" + up.nativePath + "/device/uevent" : ""
                printErrors: false
                onLoaded: {
                    const m = /^HID_UNIQ=(.*)$/m.exec(text());
                    up.address = m ? Address.find(m[1]) : "";
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
