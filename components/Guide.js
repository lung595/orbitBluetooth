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
    return { "title": (name || "This device") + " has no volume", "hint": "It does not play sound, or its audio is not ready yet", "anchor": "volume-ring" };
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
