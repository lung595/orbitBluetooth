import Quickshell
import Quickshell.Io
import "../centre"
import "Guide.js" as Guide
import "../../diagnostics/Gather.js" as Gather
import "Text.js" as Text
import "../together/Delay.js" as Delay
import "../together/Together.js" as Together
import "../together/Wired.js" as Wired
import "../noise/Anc.js" as Anc
import "../delay/LauncherWords.js" as Words
import "../device/BeamStyle.js" as BeamStyle

// The `dms ipc call orbitBluetooth ...` commands, for keyboard shortcuts.
// Kept apart from the daemon: each command only translates into a call on
// the service that owns the feature, and holds no state of its own. The
// handler sits inside a Scope that carries the services: properties declared
// on an IpcHandler itself would be listed as IPC signals.
//   anc nc | ambient | off | adaptive      ancCycle | ancStatus
//   chatEnds short | standard | long | never   wearStatus
//   deviceVolume | pcVolume | togetherVolume up | down | +5 | -5 | 40
//   volume up | down   (smart steps, D264)   volumeKeys on | off | status
//   beamStyle pulse | filament | chain | horizon | reset   (this session only)
//   hidden | unhideAll      newDeviceDemo | newDeviceStatus
//   together <devices, 2 to 4> | togetherAdd <device> | togetherRemove <device>
//   separate | togetherStatus | togetherDelay <device> <ms>
//   togetherOutputs | wiredDelay up | down | +10 | -10 | 20 | reset | status
//   (a device is a Bluetooth address or a wired output's node name)
//   disconnectIn <device> <minutes, 1 to 1440> | cancelDisconnect <device>
//   words disconnect <comma-separated words>   (the launcher words, D424; empty = defaults)
//   diagnostics   the anonymous report: the first call starts it, the next one (a
//                 couple of seconds later) hands it over (scripts/diagnose.sh does both)
// Every argument is checked and capped before it is used, and an answer never
// repeats what it was given: a name it shows is one the daemon knows, as one
// clean line (value 11).
Scope {
    id: ipc

    required property var ancService
    required property var wear
    required property var route
    required property var keys
    required property var newDevices
    required property var prefs
    required property var report
    required property var delays
    // Hands a value to the surfaces (the daemon's PluginService global)
    required property var publish

    // The group's general level, the same one the ring around the center moves
    GroupVolume {
        id: group
        session: ipc.route.together
    }

    // What a refusal says: the note, then the guide section that explains it
    function _say(note) {
        return note.title + ": " + note.hint + " · " + Guide.url(note.anchor);
    }
    // "OK", or the note of a refusal ({ why, address }) of the session
    function _answer(session, refusal) {
        return refusal ? _say(Guide.togetherNote(refusal.why, session.nameOf(refusal.address), refusal.address)) : "OK";
    }

    // What a refused delay says, then the guide section that explains it (value 10)
    function _delayNote(why) {
        const notes = {
            "bad": "Use a whole number of minutes, 1 to 1440",
            "none": "No connected device matches that name",
            "ambiguous": "Several connected devices match, type more of the name",
            "empty": "Give a device name",
            "nothing": "No disconnect is waiting for that device"
        };
        return (notes[why] || notes.empty) + " · " + Guide.url("disconnect-after-a-delay");
    }

    IpcHandler {
        target: "orbitBluetooth"

        // Tries a charging beam style until the shell restarts: it is told to
        // the scene, never saved ("reset" gives the setting back)
        function beamStyle(style: string): string {
            const s = String(style || "").trim().toLowerCase();
            if (s !== "reset" && BeamStyle.STYLES.indexOf(s) < 0)
                return "Use: beamStyle " + BeamStyle.STYLES.join(" | ") + " | reset · " + Guide.url("charging-beam");
            ipc.publish("beamStyle", s === "reset" ? "" : s);
            return "OK";
        }

        // Disconnects a connected device after a delay (D423); the answer never repeats the input
        function disconnectIn(device: string, minutes: string): string {
            const r = ipc.delays.start(String(device || "").slice(0, 120), minutes);
            return r.ok ? "OK: in " + r.minutes + " min" : ipc._delayNote(r.why);
        }

        function cancelDisconnect(device: string): string {
            const r = ipc.delays.stop(String(device || "").slice(0, 120));
            return r.ok ? "OK" : ipc._delayNote(r.why);
        }

        // Sets the launcher words of an action: the same settings key the settings page writes
        function words(action: string, list: string): string {
            const r = Words.setList(ipc.prefs.launcherWords, String(action || "").trim().toLowerCase(), String(list || "").slice(0, 400));
            if (!r.ok)
                return "Use: words " + Words.ACTIONS.join(" | ") + " <comma-separated words> · " + Guide.url("disconnect-after-a-delay");
            ipc.prefs.set("launcherWords", r.table);
            const why = r.refused.map(x => x.why).filter((w, i, all) => all.indexOf(w) === i).join(", ");
            return "OK: " + r.table[action.trim().toLowerCase()].join(", ") + (why ? " · refused: " + why + " · " + Guide.url("disconnect-after-a-delay") : "");
        }

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

        // The group's general level (the ring around the center): every output
        // moves and the gaps between them are kept
        function togetherVolume(level: string): string {
            const why = group.setLevel(level);
            return why ? Guide.levelNote(why) + " · " + Guide.url("the-volume-at-the-center") : "OK";
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

        // Names of the devices hidden in the black hole, one per line (a name
        // is the device's own: one clean line, never raw text in a terminal)
        function hidden(): string {
            const map = ipc.prefs.hiddenDevices;
            const names = Object.keys(map).map(a => Text.line(map[a]) + " (" + Text.line(a) + ")");
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

        // The wired outputs Listen together can take, as JSON, read from PipeWire
        // when asked: [{ output, name, kind, member }]. "output" is what
        // `together` and `togetherAdd` are given, "kind" is usb, hdmi, analog or
        // other, and "member" says that it already takes part.
        function togetherOutputs(): string {
            return JSON.stringify(Wired.describe(ipc.route.wiredSinks(), ipc.route.together.members));
        }

        // Nudges the automatic wait of the wired outputs, -100..+100 ms (the
        // setting of the same name, kept): one step up or down, a signed change
        // or an exact value, reset or status. Answers with the one in force.
        function wiredDelay(arg: string): string {
            const now = ipc.prefs.togetherFineDelay;
            const ms = Delay.fineFrom(arg, now);
            if (ms === null)
                return "Use: wiredDelay up | down | +10 | -10 | 20 | reset | status · " + Guide.url("wired-delay");
            if (ms !== now)
                ipc.prefs.set("togetherFineDelay", ms);
            return Delay.fineText(ms);
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
                return ipc._say(Guide.togetherNote("not-member", session.nameOf(who), who));
            if (who === session.source)
                return ipc._say(Guide.togetherNote("source", session.nameOf(who), who));
            if (!/^[0-9]{1,4}$/.test(String(ms || "").trim()) || parseInt(ms, 10) > Together.MAX_DELAY_MS)
                return "Use: togetherDelay <device> 0.." + Together.MAX_DELAY_MS + " (milliseconds) · " + Guide.url("listen-together");
            session.setDelay(who, parseInt(ms, 10));
            return "OK";
        }

        // The anonymous report (docs/DEBUGGING.md). It takes about two seconds
        // (one second of CPU measure, then a few short tools), and a call must
        // answer at once: the first call starts it, a call while it runs says
        // so, and the next one hands it over, once. Nothing is measured unless
        // this is called, and no argument is read.
        function diagnostics(): string {
            const report = ipc.report;
            if (report.report)
                return Gather.capped(report.takeReport());
            if (report.busy)
                return "Still collecting, ask again in a moment · " + Guide.url("report-a-problem");
            report.request("ipc");
            return "Collecting (about 2 s): run the same command again · " + Guide.url("report-a-problem");
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
