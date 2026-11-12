import QtQuick
import Quickshell.Io
import qs.Services
import "../common/Address.js" as Address
import "Guard.js" as Guard
import "../common/Guide.js" as Guide

// Runs after pairing and before trust: reads the device's Bluetooth
// profiles from BlueZ (P115). A "headset" that can also send key presses
// is blocked until the user confirms; many real headsets do this for their
// play/pause buttons, so it is a question, not a refusal.
// One busctl call per pairing, nothing runs otherwise.
Item {
    id: root

    readonly property string guideUrl: Guide.url("pairing-safety")

    // Checks waiting for busctl, the running one first. Two pairings can
    // overlap (two devices dragged in): one call at a time, each answer read
    // for its own device. A second check used to take over the first's call,
    // so a device that can type got the verdict of the other's profiles.
    property var _queue: []

    // done(verdict): "ok" (trust and connect), "input" (blocked, ask the
    // user, then call allow() or deny()) or "refused" (already forgotten)
    function check(device, family, done) {
        const path = device ? device.dbusPath : "";
        if (!Address.isDevicePath(path)) {
            _refuse(device, done);
            return;
        }
        _queue = _queue.concat([
            {
                "device": device,
                "family": family,
                "done": done,
                "path": path
            }
        ]);
        if (!proc.running && _queue.length === 1)
            _next();
    }

    function _next() {
        const job = _queue[0];
        if (!job || proc.running)
            return;
        proc.command = ["busctl", "--json=short", "get-property", "--", "org.bluez", job.path, "org.bluez.Device1", "UUIDs"];
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
            const job = root._queue[0] || {};
            root._queue = root._queue.slice(1);
            // Started from here the next call would not run: the process is
            // still finishing this one
            Qt.callLater(root._next);
            const d = job.device, cb = job.done;
            const uuids = code === 0 ? Guard.parseUuids(out.text) : null;
            if (!d) {
                // Gone while busctl ran (forgotten, adapter off): nothing to trust
                if (cb)
                    cb("refused");
            } else if (uuids === null) {
                root._refuse(d, cb);
            } else if (Guard.refused(job.family, uuids)) {
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
