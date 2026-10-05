import QtQuick
import QtQml
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Services
import "components/common"
import "components/noise"
import "components/pairing"
import "components/volume"
import "components/common/Address.js" as Address

// Event-driven bookkeeping shared by every surface. BlueZ exposes neither a
// connection timestamp, a charging state nor a discharge rate, so we record
// them ourselves and merge what UPower knows.
// Everything reacts to D-Bus property changes. The one timer is the short
// background scan of the "new device" pop-up (NewDeviceWatch, setting).
// The only processes are the noise-control helper (see AncService), only
// while a supported headset is connected and being controlled, and the
// opt-in picture lookup.
// Privacy: all data stays in memory for the current session; nothing is
// sent anywhere. The one exception is opt-in and off by default: with "Real
// device pictures" on, PictureService looks up the model name of paired
// devices (and of headphones the new-device pop-up offers) online and keeps the pictures in ~/.cache/orbitBluetooth.
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

    // Uninstalling erases what DMS keeps for the plugin (value 12, D259)
    UninstallSweep {
        pluginId: root.pluginId
    }

    // Noise control (ANC) for headphones: address -> helper snapshot
    Prefs {
        id: prefs
    }

    readonly property alias anc: ancService

    AncService {
        id: ancService
        active: prefs.ancEnabled
        engine: prefs.ancEngine
        chatOffOnDisconnect: prefs.ancChatOff
        publish: map => root._publish("anc", map)
    }

    // Real device pictures: off by default, the only use of the network
    PictureService {
        id: pictureService
        active: prefs.realPictures
        clearToken: prefs.picturesClear
        publish: map => root._publish("pictures", map)
    }

    readonly property alias pictureLookup: pictureService

    // The two volumes of Bluetooth audio devices: the device's own level and
    // this PC's level (D249, D255)
    AudioRoute {
        id: audioRoute
        prefs: prefs
        publish: map => root._publish("route", map)
    }

    readonly property alias route: audioRoute

    // The pop-up that shows both levels whenever one changes (D252, D258)
    // The volume keys and Orbit's smart steps, on the user's click (D265)
    VolumeKeys {
        id: keyBinder
    }

    VolumeOverlay {
        route: audioRoute
        prefs: prefs
        keys: keyBinder
    }

    // "New device nearby" pop-up, with its own background scan
    NewDeviceWatch {
        id: newDeviceWatch
        prefs: prefs
        pictureLookup: pictureService
        anc: ancService
    }

    readonly property alias newDevices: newDeviceWatch
    // The bar popout closes when the sheet comes up (OrbitBluetoothWidget):
    // a sheet stacked over the open orbit looks cluttered
    Connections {
        target: newDeviceWatch
        function onShownChanged() {
            root._publish("sheetShown", newDeviceWatch.shown);
        }
    }

    // Pairing prompts. DMS only shows its pairing dialog from the native
    // Bluetooth panel, which Orbit replaces: without this, a headset asking
    // for a passkey confirmation (e.g. FreeBuds) waits in vain, gives up and
    // retries every few seconds, which looks like random disconnects. The
    // user still accepts or declines in DMS's own dialog.
    Connections {
        target: DMSService

        function onBluetoothPairingRequest(data) {
            const modal = PopoutService.ensureBluetoothPairingModal();
            if (!modal || modal.token === data.token)
                return;
            modal.show(data);
        }
    }

    // The commands of `dms ipc call orbitBluetooth` (OrbitIpc)
    OrbitIpc {
        ancService: ancService
        route: audioRoute
        keys: keyBinder
        newDevices: newDeviceWatch
        prefs: prefs
    }

    function _publish(name, value) {
        PluginService.setGlobalVar(pluginId, name, value);
    }

    function onConnection(device, connected) {
        if (!device || !device.address)
            return;
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
        if (!device || !device.address || percent < 0 || !device.connected)
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

            readonly property var info: (address && modelData && !modelData.isLaptopBattery) ? {
                "state": modelData.state ?? 0,
                "percentage": (modelData.percentage ?? 0) > 0 ? Math.round(modelData.percentage * 100) : -1,
                "timeToFull": modelData.timeToFull ?? 0,
                "timeToEmpty": modelData.timeToEmpty ?? 0,
                "changeRate": Math.abs(modelData.changeRate ?? 0),
                "health": modelData.healthSupported ? (modelData.healthPercentage ?? -1) : -1
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

            onConnectedChanged: if (modelData) root.onConnection(modelData, connected)
            onPercentChanged: if (modelData) root.onBattery(modelData, percent)

            Component.onCompleted: {
                if (modelData) {
                    if (connected)
                        root.onConnection(modelData, true);
                    root.onBattery(modelData, percent);
                }
            }
        }
    }
}
