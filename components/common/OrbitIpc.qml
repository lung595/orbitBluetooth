import Quickshell.Io
import "Guide.js" as Guide
import "../noise/Anc.js" as Anc

// The `dms ipc call orbitBluetooth ...` commands, for keyboard shortcuts.
// Kept apart from the daemon: each command only translates into a call on
// the service that owns the feature, and holds no state of its own.
//   anc nc | ambient | off | adaptive      ancCycle | ancStatus
//   deviceVolume | pcVolume up | down | +5 | -5 | 40
//   volume up | down   (smart steps, D264)   volumeKeys on | off | status
//   hidden | unhideAll      newDeviceDemo | newDeviceStatus
IpcHandler {
    required property var ancService
    required property var route
    required property var keys
    required property var newDevices
    required property var prefs

    target: "orbitBluetooth"

    // Shows the new-device pop-up with a made-up headset
    function newDeviceDemo(): string {
        return newDevices.demo();
    }

    // Why the pop-up's last background scan was skipped, if it was
    function newDeviceStatus(): string {
        return JSON.stringify({
            "enabled": newDevices.offering,
            "backgroundScan": newDevices.prefs.offerScan,
            "lastScan": newDevices.lastSkip ? "skipped: " + newDevices.lastSkip : "ran",
            "showing": newDevices.current,
            "phase": newDevices.current ? newDevices.phase : "",
            "lastError": newDevices.lastError
        });
    }

    function anc(mode: string): string {
        const address = ancService.primary();
        if (!address)
            return "No supported headset connected · " + Guide.url("noise-control");
        if (Anc.ORDER.indexOf(mode) < 0)
            return "Modes: " + Anc.ORDER.join(", ") + " · " + Guide.url("noise-control");
        ancService.send(address, "mode", mode);
        return "OK";
    }

    // Next mode on the first connected headset (off is skipped when possible)
    function ancCycle(): string {
        const address = ancService.primary();
        if (!address)
            return "No supported headset connected · " + Guide.url("noise-control");
        ancService.cycle(address);
        return "OK";
    }

    // The level inside the Bluetooth device in use (absolute volume)
    function deviceVolume(level: string): string {
        const why = route.setLevel("device", level, "");
        return why ? Guide.levelNote(why) + " · " + Guide.url("the-two-volumes") : "OK";
    }

    // What this PC sends to it (or to the current output with no device)
    function pcVolume(level: string): string {
        const why = route.setLevel("pc", level, "");
        return why ? Guide.levelNote(why) + " · " + Guide.url("the-two-volumes") : "OK";
    }

    // The level heard: the device's own when it has one, else this PC's.
    // Bound to the volume keys, a slow press is 1 %, a fast run speeds up
    // Binds the volume keys to Orbit's smart steps ("on"), gives them
    // back to DMS ("off"), or tells what they do now ("status")
    function volumeKeys(arg: string): string {
        const a = String(arg || "").trim().toLowerCase();
        if (a === "on")
            keys.enable();
        else if (a === "off")
            keys.disable();
        else if (a !== "status")
            return "Use: volumeKeys on | off | status · " + Guide.url("volume-keys");
        return a === "status" ? keys.keys : "OK";
    }

    function volume(direction: string): string {
        const d = String(direction || "").trim().toLowerCase();
        if (d !== "up" && d !== "down")
            return "Use: volume up | down · " + Guide.url("smart-volume-steps");
        const why = route.stepHeard(d === "up" ? 1 : -1);
        return why ? Guide.levelNote(why) + " · " + Guide.url("the-two-volumes") : "OK";
    }

    // Names of the devices hidden in the black hole, one per line
    function hidden(): string {
        const map = prefs.hiddenDevices;
        const names = Object.keys(map).map(a => map[a] + " (" + a + ")");
        return names.length ? names.join("\n") : "No hidden devices";
    }

    // Brings every hidden device back into the orbit
    function unhideAll(): string {
        prefs.set("hiddenDevices", ({}));
        return "OK";
    }

    function ancStatus(): string {
        const address = ancService.primary();
        const s = ancService.snapshots[address];
        if (!address)
            return "No supported headset connected · " + Guide.url("noise-control");
        if (!s || !s.state)
            return "Unknown (open the headset card once, or use the always-connected engine) · " + Guide.url("noise-control");
        return JSON.stringify(s.state);
    }
}
