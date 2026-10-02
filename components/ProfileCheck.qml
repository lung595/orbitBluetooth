import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import "Guard.js" as Guard

// Runs after pairing and before trust: reads the device's Bluetooth
// profiles from BlueZ (P115). A "headset" that can also send key presses
// is blocked until the user confirms; many real headsets do this for their
// play/pause buttons, so it is a question, not a refusal.
// One busctl call per pairing, nothing runs otherwise.
Item {
    id: root

    readonly property string guideUrl: "https://github.com/lung595/orbitBluetooth/blob/main/docs/GUIDE.md#pairing-safety"

    property var _device: null
    property string _family: ""
    property var _done: null

    // done(verdict): "ok" (trust and connect), "input" (blocked, ask the
    // user, then call allow() or deny()) or "refused" (already forgotten)
    function check(device, family, done) {
        const path = device ? device.dbusPath : "";
        if (!Guard.validPath(path)) {
            _refuse(device, done);
            return;
        }
        _device = device;
        _family = family;
        _done = done;
        proc.command = ["busctl", "--json=short", "get-property", "--", "org.bluez", path, "org.bluez.Device1", "UUIDs"];
        proc.running = true;
    }

    // The user confirmed it is their headset
    function allow(device) {
        if (device)
            device.blocked = false;
    }

    // The user said no, or never answered
    function deny(device) {
        if (!device)
            return;
        device.trusted = false;
        device.forget();
        device.blocked = false;
    }

    // Could not read its profiles: do not trust what cannot be checked
    function _refuse(device, done) {
        deny(device);
        if (typeof ToastService !== "undefined")
            ToastService.showWarning("Orbit: could not check this device, so it was not paired", guideUrl);
        if (done)
            done("refused");
    }

    Process {
        id: proc
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            const d = root._device, cb = root._done;
            root._device = null;
            root._done = null;
            const uuids = code === 0 ? Guard.parseUuids(out.text) : null;
            if (uuids === null) {
                root._refuse(d, cb);
            } else if (Guard.refused(root._family, uuids)) {
                // BlueZ drops every connection from a blocked device, the
                // keyboard profile included, while the user decides
                d.trusted = false;
                d.blocked = true;
                if (cb)
                    cb("input");
            } else if (cb) {
                cb("ok");
            }
        }
    }
}
