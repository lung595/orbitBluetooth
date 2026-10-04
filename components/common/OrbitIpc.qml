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
//   chatEnds short | standard | long | never   wearStatus
//   deviceVolume | pcVolume up | down | +5 | -5 | 40
//   volume up | down   (smart steps, D264)   volumeKeys on | off | status
//   hidden | unhideAll      newDeviceDemo | newDeviceStatus
//   together <devices, 2 to 4> | togetherAdd <device> | togetherRemove <device>
//   separate | togetherStatus | togetherDelay <device> <ms>
//   (a device is a Bluetooth address or a wired output's node name)
Scope {
    id: ipc

    required property var ancService
    required property var wear
    required property var route
    required property var keys
    required property var newDevices
    required property var prefs

    // What a refusal says: the note, then the guide section that explains it
    function _say(note) {
        return note.title + ": " + note.hint + " · " + Guide.url(note.anchor);
    }
    // "OK", or the note of a refusal ({ why, address }) of the session
    function _answer(session, refusal) {
        return refusal ? _say(Guide.togetherNote(refusal.why, session.nameOf(refusal.address))) : "OK";
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

        // How long a Speak-to-Chat conversation lasts before it ends by itself
        function chatEnds(duration: string): string {
            const index = Anc.chatEndsIndex(duration);
            const url = Guide.url("how-long-a-conversation-lasts");
            if (index < 0)
                return "Use: chatEnds " + Anc.CHAT_ENDS.join(" | ") + " · " + url;
            const address = ipc.ancService.primary("sony");
            const known = address ? ipc.ancService.snapshots[address] : null;
            if (!known || !known.features || !known.features.chatEnds)
                return "No headset has said how long a conversation lasts (open its card once) · " + url;
            return ipc.ancService.send(address, "chatEnds", index) ? "OK" : "The headset is not reachable right now · " + url;
        }

        // What pause-on-removal sees: the headset's state, and how many
        // players it holds paused. The raw status code helps to check a model.
        function wearStatus(): string {
            const url = Guide.url("pause-when-you-take-the-headset-off");
            if (!ipc.prefs.wearPause)
                return "Pause on removal is off (Settings, Headphones) · " + url;
            if (!ipc.prefs.ancEnabled)
                return "Noise control is off: pause on removal uses its connection · " + url;
            const address = ipc.ancService.primary("sony");
            if (!address)
                return "No Sony headset connected · " + url;
            const report = ipc.wear.statusOf(address);
            if (report.state === "waiting")
                return "Waiting for the headset to answer · " + url;
            if (report.state === "error")
                return "Could not reach the headset · " + url;
            if (report.state === "unsupported")
                return "This headset does not report wearing · " + url;
            return JSON.stringify(report);
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

        // Plays the same sound on 2 to 4 connected outputs, Bluetooth or wired
        // (Listen together). One argument: the devices, separated by commas or
        // spaces: Bluetooth addresses, or the node names of wired outputs
        // ("alsa_output.…"). Anything else is refused by Together.refusal.
        function together(members: string): string {
            const session = ipc.route.together;
            return ipc._answer(session, session.start(Together.parseList(members)));
        }

        // Adds one connected output (a Bluetooth address or a wired output's
        // node name) to the session
        function togetherAdd(device: string): string {
            const session = ipc.route.together;
            return ipc._answer(session, session.add([device]));
        }

        // Takes one output out of the session; it ends if fewer than two remain
        function togetherRemove(device: string): string {
            const session = ipc.route.together;
            return ipc._answer(session, session.remove(device));
        }

        // Ends Listen together; every output goes back to itself
        function separate(): string {
            return ipc.route.together.end("ended", "") ? "OK" : ipc._say(Guide.togetherNote("none", ""));
        }

        // Who listens together now, as JSON
        function togetherStatus(): string {
            return Together.status(ipc.route.together.active ? ipc.route.together : null);
        }

        // Delays what one member plays by 0..1000 ms for this session only
        // (nothing is saved), on top of the wait Orbit works out for a wired
        // output; the output the sound is taken from has no delay of its own
        function togetherDelay(device: string, ms: string): string {
            const session = ipc.route.together;
            const who = Together.member(device);
            if (!session.active)
                return ipc._say(Guide.togetherNote("no-session", ""));
            if (!session.isMember(who))
                return ipc._say(Guide.togetherNote("not-member", session.nameOf(who)));
            if (who === session.source)
                return ipc._say(Guide.togetherNote("source", session.nameOf(session.source)));
            if (!/^[0-9]{1,4}$/.test(String(ms || "").trim()) || parseInt(ms, 10) > Together.MAX_DELAY_MS)
                return "Use: togetherDelay <device> 0.." + Together.MAX_DELAY_MS + " (milliseconds) · " + Guide.url("listen-together");
            session.setDelay(who, parseInt(ms, 10));
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
