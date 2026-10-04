import Quickshell
import Quickshell.Io
import "Guide.js" as Guide
import "../together/Together.js" as Together
import "../noise/Anc.js" as Anc

// The `dms ipc call orbitBluetooth ...` commands, for keyboard shortcuts.
// Kept apart from the daemon: each command only translates into a call on
// the service that owns the feature, and holds no state of its own. The
// handler sits inside a Scope that carries the services: properties declared
// on an IpcHandler itself would be listed as IPC signals.
//   anc nc | ambient | off | adaptive      ancCycle | ancStatus
//   deviceVolume | pcVolume up | down | +5 | -5 | 40
//   volume up | down   (smart steps, D264)   volumeKeys on | off | status
//   hidden | unhideAll      newDeviceDemo | newDeviceStatus
//   together <addressA> <addressB> | separate | togetherStatus | togetherDelay <ms>
Scope {
    id: ipc

    required property var ancService
    required property var route
    required property var keys
    required property var newDevices
    required property var prefs

    // What a refusal says: the note, then the guide section that explains it
    function _say(note) {
        return note.title + ": " + note.hint + " · " + Guide.url(note.anchor);
    }

    IpcHandler {
        target: "orbitBluetooth"

        // Shows the new-device pop-up with a made-up headset
        function newDeviceDemo(): string {
            return ipc.newDevices.demo();
        }

        // Why the pop-up's last background scan was skipped, if it was
        function newDeviceStatus(): string {
            return JSON.stringify({
                "enabled": ipc.newDevices.offering,
                "backgroundScan": ipc.newDevices.prefs.offerScan,
                "lastScan": ipc.newDevices.lastSkip ? "skipped: " + ipc.newDevices.lastSkip : "ran",
                "showing": ipc.newDevices.current,
                "phase": ipc.newDevices.current ? ipc.newDevices.phase : "",
                "lastError": ipc.newDevices.lastError
            });
        }

        function anc(mode: string): string {
            const address = ipc.ancService.primary();
            if (!address)
                return "No supported headset connected · " + Guide.url("noise-control");
            if (Anc.ORDER.indexOf(mode) < 0)
                return "Modes: " + Anc.ORDER.join(", ") + " · " + Guide.url("noise-control");
            ipc.ancService.send(address, "mode", mode);
            return "OK";
        }

        // Next mode on the first connected headset (off is skipped when possible)
        function ancCycle(): string {
            const address = ipc.ancService.primary();
            if (!address)
                return "No supported headset connected · " + Guide.url("noise-control");
            ipc.ancService.cycle(address);
            return "OK";
        }

        // The level inside the Bluetooth device in use (absolute volume)
        function deviceVolume(level: string): string {
            const why = ipc.route.setLevel("device", level, "");
            return why ? Guide.levelNote(why) + " · " + Guide.url("the-two-volumes") : "OK";
        }

        // What this PC sends to it (or to the current output with no device)
        function pcVolume(level: string): string {
            const why = ipc.route.setLevel("pc", level, "");
            return why ? Guide.levelNote(why) + " · " + Guide.url("the-two-volumes") : "OK";
        }

        // The level heard: the device's own when it has one, else this PC's.
        // Bound to the volume keys, a slow press is 1 %, a fast run speeds up
        // Binds the volume keys to Orbit's smart steps ("on"), gives them
        // back to DMS ("off"), or tells what they do now ("status")
        function volumeKeys(arg: string): string {
            const a = String(arg || "").trim().toLowerCase();
            if (a === "on")
                ipc.keys.enable();
            else if (a === "off")
                ipc.keys.disable();
            else if (a !== "status")
                return "Use: volumeKeys on | off | status · " + Guide.url("volume-keys");
            return a === "status" ? ipc.keys.keys : "OK";
        }

        function volume(direction: string): string {
            const d = String(direction || "").trim().toLowerCase();
            if (d !== "up" && d !== "down")
                return "Use: volume up | down · " + Guide.url("smart-volume-steps");
            const why = ipc.route.stepHeard(d === "up" ? 1 : -1);
            return why ? Guide.levelNote(why) + " · " + Guide.url("the-two-volumes") : "OK";
        }

        // Names of the devices hidden in the black hole, one per line
        function hidden(): string {
            const map = ipc.prefs.hiddenDevices;
            const names = Object.keys(map).map(a => map[a] + " (" + a + ")");
            return names.length ? names.join("\n") : "No hidden devices";
        }

        // Brings every hidden device back into the orbit
        function unhideAll(): string {
            ipc.prefs.set("hiddenDevices", ({}));
            return "OK";
        }

        // Plays the same sound on two connected Bluetooth outputs (Listen together)
        function together(first: string, second: string): string {
            const session = ipc.route.together;
            const r = session.check(first, second);
            if (r)
                return ipc._say(Guide.togetherNote(r.why, session.nameOf(r.address)));
            session.start(first, second);
            return "OK";
        }

        // Ends Listen together; every output goes back to itself
        function separate(): string {
            return ipc.route.together.end("ended", "") ? "OK" : ipc._say(Guide.togetherNote("none", ""));
        }

        // Who listens together now, as JSON
        function togetherStatus(): string {
            return Together.status(ipc.route.together.active ? ipc.route.together : null);
        }

        // Delays the copy by 0..500 ms for this session only (nothing is saved)
        function togetherDelay(ms: string): string {
            const session = ipc.route.together;
            if (!session.active)
                return ipc._say(Guide.togetherNote("none", ""));
            if (!/^[0-9]{1,3}$/.test(String(ms || "").trim()) || parseInt(ms, 10) > Together.MAX_DELAY_MS)
                return "Use: togetherDelay 0..500 (milliseconds) · " + Guide.url("listen-together");
            session.setDelay(parseInt(ms, 10));
            return "OK";
        }

        function ancStatus(): string {
            const address = ipc.ancService.primary();
            const s = ipc.ancService.snapshots[address];
            if (!address)
                return "No supported headset connected · " + Guide.url("noise-control");
            if (!s || !s.state)
                return "Unknown (open the headset card once, or use the always-connected engine) · " + Guide.url("noise-control");
            return JSON.stringify(s.state);
        }
    }
}
