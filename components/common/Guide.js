.pragma library

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

// Pulled out of its orbit, but still connected a while later
function stuckNote(name) {
    return { "title": (name || "This device") + " is still connected", "hint": "It may be in use: try again, or turn it off", "anchor": "if-it-does-not-disconnect" };
}

// A level that cannot be set from the keyboard, by why (AudioRoute.setLevel)
function levelNote(why) {
    if (why === "no-device")
        return "No Bluetooth audio device connected";
    if (why === "no-own-volume")
        return "This device has no volume of its own: it follows this PC's level";
    if (why === "no-pc-level")
        return "Separate PC volume is off: this device has one level, use deviceVolume";
    return "Use up, down, +5, -5 or a level from 0 to 100";
}

// Listen together could not start, a device could not join, or a member
// left or the session ended (Together.refusal / joinRefusal and the
// session): never a silent refusal (value 10). The multipoint section
// explains an output that is away because the headset serves the phone.
function togetherNote(why, name) {
    var who = name || "This device";
    var notes = {
        "same": { "title": "Pick different devices", "hint": "Drag one device onto another" },
        "bad-address": { "title": "Not a device address", "hint": "Use addresses like AA:BB:CC:DD:EE:FF" },
        "too-few": { "title": "Listening together needs two devices", "hint": "Drag one device onto another" },
        "too-many": { "title": "Up to 4 devices listen together", "hint": "Let one leave first: right-click it, then Leave together" },
        "outside": { "title": "Drop it onto a device that listens together", "hint": "Only one group listens together: drag it onto a member, or stop the group first" },
        "already": { "title": who + " already listens together", "hint": "Drag another device onto it to add that one" },
        "not-member": { "title": who + " is not listening together", "hint": "Only a device in the session can leave it" },
        "no-session": { "title": "Nobody listens together yet", "hint": "Drag one connected device onto another first" },
        "not-connected": { "title": who + " is not connected", "hint": "Connect it first, then drag it onto a device that listens" },
        "no-audio": { "title": who + " has no sound output yet", "hint": "It does not play sound, or its audio is not ready: try again in a moment", "anchor": "works-with-multipoint-headsets" },
        "in-call": { "title": who + " is in call mode", "hint": "A headset on its call profile plays mono: switch it back to music first" },
        "member-out": { "title": who + " disconnected", "hint": "The others keep listening together" },
        "member-left": { "title": who + " disconnected", "hint": "Listening together ended with it" },
        "link-stopped": { "title": "Listening together stopped", "hint": "The copy of the sound ended: drag a device onto another to start again" },
        "none": { "title": "Nothing is shared", "hint": "Drag a connected device onto another to listen together" }
    };
    var n = notes[why] || notes["link-stopped"];
    return { "title": n.title, "hint": n.hint, "anchor": n.anchor || "listen-together" };
}
