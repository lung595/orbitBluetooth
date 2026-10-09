.pragma library
.import "../together/Together.js" as Together
.import "../together/Member.js" as Member

// Links into docs/GUIDE.md, opened in the browser on click only: Orbit
// itself never goes online for them (values 5 and 10)
var BASE = "https://github.com/lung595/orbitBluetooth/blob/main/docs/GUIDE.md";

// A section of the guide; its title is the anchor, so titles stay stable
function url(anchor) {
    return anchor ? BASE + "#" + anchor : BASE;
}

// What to say when a device dragged in did not connect, by what failed:
// "pair" (BlueZ refused or timed out), "check" (its services could not be
// read), "connect" (paired but no connection in time)
function connectNote(why, name) {
    var who = name || "This device";
    if (why === "check")
        return { "title": who + " was not paired", "hint": "Its services could not be checked", "anchor": "pairing-safety" };
    if (why === "connect")
        return { "title": who + " did not connect", "hint": "Is it on, and close by?", "anchor": "if-it-does-not-connect" };
    return { "title": "Could not pair " + (name || "this device"), "hint": "Put it in pairing mode, then drag it in again", "anchor": "if-it-does-not-connect" };
}

// "Turn on" was pressed but Bluetooth stayed off: something blocks it
// (airplane mode, a hardware switch, rfkill)
function blockedNote() {
    return { "title": "Bluetooth stayed off", "hint": "Airplane mode or a switch may block it", "anchor": "bluetooth-is-off" };
}

// Scrolled over a connected device that has no sound output to set
function noVolumeNote(name) {
    return { "title": (name || "This device") + " has no volume", "hint": "It does not play sound, or its audio is not ready yet", "anchor": "the-two-volumes" };
}

// Scrolled over a copy at the centre of a Listen together that has no level
// of its own (it follows this PC's level, which the ring sets for everyone)
function copyLevelNote(name) {
    return { "title": (name || "This device") + " has no volume of its own", "hint": "It follows the group: turn the ring around the center", "anchor": "the-volume-at-the-center" };
}

// Two Bluetooth outputs play at once on one adapter (RadioWatch): the radio
// is shared, a heavy codec such as LDAC may lose quality or cut. Said once
// per pair; Orbit lowers nothing.
function radioNote() {
    return { "title": "Two outputs share one Bluetooth radio", "hint": "Quality may drop or cut: a second adapter gives each its own", "anchor": "two-outputs-one-radio" };
}

// Pulled out of its orbit, but still connected a while later
function stuckNote(name) {
    return { "title": (name || "This device") + " is still connected", "hint": "It may be in use: try again, or turn it off", "anchor": "if-it-does-not-disconnect" };
}

// A level that cannot be set from the keyboard, by why (AudioRoute.setLevel,
// GroupVolume.setLevel)
function levelNote(why) {
    if (why === "no-device")
        return "No Bluetooth audio device connected";
    if (why === "no-own-volume")
        return "This device has no volume of its own: it follows this PC's level";
    if (why === "no-pc-level")
        return "Separate PC volume is off: this device has one level, use deviceVolume";
    if (why === "no-group")
        return "No group is playing: use together first";
    return "Use up, down, +5, -5 or a level from 0 to 100";
}

// The notes of Listen together that read differently for a wired output
// (D298): it is plugged in and unplugged, never connected, and the wait that
// lines it up is Orbit's to work out, the user only nudges it. null for a
// reason that reads the same for both kinds.
function wiredNote(why, name) {
    var who = name || "This output";
    var notes = {
        "not-connected": { "title": who + " is not plugged in", "hint": "Plug it in and let it show in the sound settings, then add it again", "anchor": "wired-outputs" },
        "no-latency": { "title": who + " reports no delay", "hint": "Hold the early output back by hand if you hear an echo", "anchor": "limits" },
        "member-out": { "title": who + " was unplugged", "hint": "The others keep listening together", "anchor": "wired-outputs" },
        "member-left": { "title": who + " was unplugged", "hint": "Listening together ended with it", "anchor": "wired-outputs" },
        "source": { "title": who + " is where the sound comes from", "hint": "Orbit sets its wait; nudge it with Wired delay in the settings", "anchor": "wired-delay" }
    };
    return notes[why] || null;
}

// Listen together could not start, a device could not join, or a member
// left or the session ended (Together.refusal / joinRefusal and the
// session): never a silent refusal (value 10). The multipoint section
// explains an output that is away because the headset serves the phone.
// `member` is the output the note is about when there is one (a Bluetooth
// address or a wired output's node name, Member.js): a wired one is told in
// its own words.
function togetherNote(why, name, member) {
    var wired = Member.isWired(member) ? wiredNote(why, name) : null;
    if (wired)
        return wired;
    var who = name || "This device";
    var notes = {
        "same": { "title": "Pick different devices", "hint": "Drag one device onto another" },
        "bad-address": { "title": "Not a Bluetooth or wired output", "hint": "Use an address like AA:BB:CC:DD:EE:FF, or the name of a wired output (alsa_output.…)" },
        "too-few": { "title": "Listening together needs two devices", "hint": "Drag one device onto another" },
        "too-many": { "title": "Up to " + Together.MAX_MEMBERS + " devices listen together", "hint": "Let one leave first: drag it out, or right-click it, then Remove from group" },
        "outside": { "title": "Drop it onto a device that listens together", "hint": "Only one group listens together: drag it onto a member, or stop the group first" },
        "already": { "title": who + " already listens together", "hint": "Drag another device onto it to add that one" },
        "in-group": { "title": who + " listens together", "hint": "Pull it out of the group first (drag it out, or right-click, Remove from group), then hide it", "anchor": "hiding-devices-the-black-hole" },
        "hidden-full": { "title": "Too many hidden devices", "hint": "Bring one back first: click the black hole, then Show", "anchor": "hiding-devices-the-black-hole" },
        "not-member": { "title": who + " is not listening together", "hint": "Only a device in the session can leave it" },
        "no-session": { "title": "Nobody listens together yet", "hint": "Drag one connected device onto another first" },
        "not-connected": { "title": who + " is not connected", "hint": "Connect it (or plug it in, for a wired output) first, then drag it onto a device that listens" },
        "no-audio": { "title": who + " has no sound output yet", "hint": "It does not play sound, or its audio is not ready: try again in a moment", "anchor": "works-with-multipoint-headsets" },
        "in-call": { "title": who + " is in call mode", "hint": "A headset on its call profile plays mono: switch it back to music first" },
        "source": { "title": who + " is where the sound comes from", "hint": "Only the other outputs can be held back by hand: make another one the output you hear, or hold the early one back", "anchor": "limits" },
        "no-latency": { "title": who + " reports no delay", "hint": "Hold the early output back by hand if you hear an echo", "anchor": "limits" },
        "member-out": { "title": who + " disconnected", "hint": "The others keep listening together" },
        "member-left": { "title": who + " disconnected", "hint": "Listening together ended with it" },
        "link-stopped": { "title": "Listening together stopped", "hint": "The copy of the sound ended: drag a device onto another to start again" },
        "none": { "title": "Nothing is shared", "hint": "Drag a connected device onto another to listen together" },
        // The group chooser (GroupChooser): too little ticked, or no room left in the group
        "pick-more": { "title": "Tick another output", "hint": "Tick the outputs that should play together, then press the button" },
        "full": { "title": "The group is full", "hint": "Up to " + Together.MAX_MEMBERS + " devices listen together: untick one, or let a member leave" }
    };
    var n = notes[why] || notes["link-stopped"];
    return { "title": n.title, "hint": n.hint, "anchor": n.anchor || "listen-together" };
}

// What the "Copy report" button says, by what the copy is doing: "idle",
// "collecting", "copied" (with inHistory: only DMS's own copy worked, so its
// clipboard history may keep the text) or "none" (no tool could copy it)
function reportNote(state, inHistory) {
    var anchor = "report-a-problem";
    if (state === "collecting")
        return { "title": "Collecting the report", "hint": "About two seconds", "anchor": anchor };
    if (state === "copied")
        return { "title": "Report copied", "hint": inHistory ? "Read it, then paste it in a GitHub issue. It holds nothing personal, but DMS's clipboard history may keep it" : "Read it, then paste it in a GitHub issue", "anchor": anchor };
    if (state === "none")
        return { "title": "The report could not be copied", "hint": "Install wl-clipboard, or run dms ipc call orbitBluetooth diagnostics in a terminal", "anchor": anchor };
    return { "title": "Anonymous report", "hint": "Versions, states and codes only, to paste in a GitHub issue", "anchor": anchor };
}
