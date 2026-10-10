import QtQuick
import qs.Services
import "components/common"
import "components/delay"
import "components/noise"
import "components/pairing"
import "components/together"
import "components/volume"
import "components/wear"
import "diagnostics/Log.js" as Log

// Event-driven bookkeeping shared by every surface. BlueZ exposes neither a
// connection timestamp, a charging state nor a discharge rate, so we record
// them ourselves and merge what UPower knows.
// Everything reacts to D-Bus property changes. The one timer is the short
// background scan of the "new device" pop-up (NewDeviceWatch, setting).
// The only processes are the noise-control helper (see AncService), only
// while a supported headset is connected and being controlled (or, with
// "Pause when you take the headset off" on, while a Sony headset with a
// wearing sensor is connected), and the opt-in picture lookup.
// Privacy: all data stays in memory for the current session; nothing is
// sent anywhere. The one exception is opt-in and off by default: with "Real
// device pictures" on, PictureService looks up the model name of paired
// devices (and of headphones the new-device pop-up offers) online and keeps the pictures in ~/.cache/orbitBluetooth.
Item {
    id: root

    // One memory write each way: which surfaces are alive shows in a report
    Component.onCompleted: Log.event("ORB-I020", {
        "surface": "daemon"
    })
    Component.onDestruction: Log.event("ORB-I021", {
        "surface": "daemon"
    })

    property var pluginService: null
    property string pluginId: "orbitBluetooth"

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
        wearPause: prefs.wearPause
        publish: map => root._publish("anc", map)
    }

    // Pauses the music when a Sony headset comes off, resumes it on return
    WearPause {
        id: wearPause
        ancService: ancService
        together: audioRoute.together
        active: prefs.wearPause
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

    // What the user listens to together, kept for the ghost group (D299)
    HabitLog {
        session: audioRoute.together
        prefs: prefs
    }

    // The pop-up that shows both levels whenever one changes (D252, D258)
    // The volume keys and Orbit's smart steps: Orbit's from the first start
    // unless the user gave them back (D265, NAK-214)
    VolumeKeys {
        id: keyBinder
        prefs: prefs
        Component.onCompleted: claim()
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

    // The anonymous report, built only when asked for (docs/DEBUGGING.md)
    ReportService {
        id: reportService
        prefs: prefs
        surfaces: ({
                "daemon": true
            })
    }

    // "Disconnect after a delay": one single-shot timer per pending delay (D423)
    DisconnectDelays {
        id: disconnectDelays
        publish: map => root._publish("disconnectDelays", {
                "ends": map,
                "sands": disconnectDelays.sandsInstalled
            })
    }

    // The commands of `dms ipc call orbitBluetooth` (OrbitIpc)
    OrbitIpc {
        ancService: ancService
        wear: wearPause
        route: audioRoute
        keys: keyBinder
        newDevices: newDeviceWatch
        prefs: prefs
        report: reportService
        delays: disconnectDelays
        publish: (name, value) => root._publish(name, value)
    }

    function _publish(name, value) {
        PluginService.setGlobalVar(pluginId, name, value);
    }

    // Connection times, battery history and UPower facts of every device
    DeviceLog {
        publish: (name, value) => root._publish(name, value)
    }
}
