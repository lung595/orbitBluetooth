import QtQuick
import qs.Services
import "../pairing"
import "../common/Guide.js" as Guide
import "../device/DeviceCatalog.js" as Catalog

// The connection flow behind the drag gestures: pair (after checking the
// device cannot also type, P115), connect, disconnect, cancel, forget, and
// what to say when one of them fails or never lands. Nothing runs between
// requests: each timer is a one-shot armed by one.
Item {
    id: connections
    required property var scene
    required property Repeater bodies   // the device bodies

    function startConnect(b) {
        if (!b || !b.device || b.connected || b.phase === "connecting")
            return;
        const d = b.device;
        b.phase = "connecting";
        pendingTimer.restart();
        connections.scene.wake();
        if (d.paired || d.bonded) {
            // Second drag of a headset that can also type: the user confirms
            if (d === _confirm) {
                confirmWait.stop();
                _confirm = null;
                profileCheck.allow(d);
            }
            BluetoothService.connectDeviceWithTrust(d);
            return;
        }
        BluetoothService.pairDevice(d, res => {
            // The user may have pulled it back out while pairing was in flight
            if (b.phase !== "connecting")
                return;
            if (res && res.error) {
                failConnect(b, "pair");
                return;
            }
            // Trust only after checking it cannot also type (P115)
            profileCheck.check(d, Catalog.families[Catalog.resolve(d, ({}))] || "", verdict => {
                if (verdict === "input") {
                    // Blocked until it is dragged in again, or forgotten
                    connections._confirm = d;
                    confirmWait.restart();
                    if (typeof ToastService !== "undefined")
                        ToastService.showWarning("Orbit: it can also send key presses, often for its buttons. Drag it in again within a minute to pair it anyway", profileCheck.guideUrl);
                    failConnect(b);
                    return;
                }
                if (verdict !== "ok") {
                    failConnect(b, "check");
                    return;
                }
                if (b.phase === "connecting" && !d.connected)
                    BluetoothService.connectDeviceWithTrust(d);
            });
        });
    }

    // A "headset" with a keyboard profile, waiting for a second drag (P115)
    property var _confirm: null
    Timer {
        id: confirmWait
        interval: 60000
        onTriggered: {
            profileCheck.deny(connections._confirm);
            connections._confirm = null;
        }
    }

    // why: "pair", "check" or "connect" (Guide.connectNote); omitted when
    // something else already said why (the keyboard-profile toast)
    function failConnect(b, why) {
        if (!b || b.phase !== "connecting")
            return;
        if (why)
            connections.scene.explain(Guide.connectNote(why, b.device ? Catalog.deviceName(b.device) : ""));
        b.phase = "idle";
        b.shake();
        connections.scene.sounds.play("error");
        connections.scene.wake();
    }

    // Abort an in-flight pairing/connection (device pulled back out of the belt)
    function cancelConnect(b) {
        if (!b || b.phase !== "connecting")
            return;
        const d = b.device;
        b.phase = "idle";
        b.cancelledAt = Date.now();
        if (d) {
            if (d.pairing)
                d.cancelPair();
            d.disconnect();
        }
        b.release();
        connections.scene.emitWave(false);
        connections.scene.sounds.play("disconnect");
        connections.scene.wake();
    }

    function startDisconnect(b) {
        if (!b || !b.device || !b.connected)
            return;
        b.phase = "disconnecting";
        disconnectWatch.body = b;
        disconnectWatch.restart();
        if (connections.scene.ancService && connections.scene.ancCapable(b))
            connections.scene.ancService.disconnectDevice(b.address);
        else
            b.device.disconnect();
        connections.scene.wake();
    }

    // A disconnect that never lands (device busy, BlueZ refusing) would leave
    // the planet out of its slot while still connected: after 8 s it comes
    // back and says so. One shot per pull, nothing runs otherwise.
    Timer {
        id: disconnectWatch
        property var body: null
        interval: 8000
        onTriggered: {
            const b = body;
            body = null;
            if (!b || b.phase !== "disconnecting" || !b.connected)
                return;
            b.phase = "idle";
            b.shake();
            connections.scene.sounds.play("error");
            connections.scene.explain(Guide.stuckNote(b.device ? Catalog.deviceName(b.device) : ""));
            connections.scene.wake();
        }
    }

    // Unpairs the device, and drops what Orbit kept about it (its icon
    // choice, the "Don't offer again" mark), so it comes back as new
    function forget(b) {
        if (!b || !b.device)
            return;
        connections.scene.clearFocus();
        connections.scene.prefs.setGlyphOverride(b.address, "auto");
        if (connections.scene.prefs.ignoredDevices[b.address] !== undefined)
            connections.scene.prefs.setIgnored(b.address, "", false);
        b.device.forget();
    }

    // Any connection edge, including ones made elsewhere (auto-reconnect)
    function onBodyConnectionChanged(b, isConnected) {
        // BlueZ can still land a connection right after a cancel: undo it quietly
        if (isConnected && Date.now() - b.cancelledAt < 6000) {
            b.device.disconnect();
            return;
        }
        if (isConnected) {
            b.phase = "idle";
            b.celebrate();
            connections.scene.world.pulseCore();
            connections.scene.emitWave(true);
            connections.scene.sounds.play("connect");
        } else {
            b.phase = "idle";
            b.release();
            connections.scene.emitWave(false);
            connections.scene.sounds.play("disconnect");
        }
        connections.scene.wake();
    }

    Timer {
        id: pendingTimer
        interval: 25000
        onTriggered: {
            for (let i = 0; i < connections.bodies.count; i++) {
                const b = connections.bodies.itemAt(i);
                if (b && b.phase === "connecting" && !b.connected)
                    connections.failConnect(b, b.device && (b.device.paired || b.device.bonded) ? "connect" : "pair");
            }
        }
    }

    ProfileCheck {
        id: profileCheck
    }
}
