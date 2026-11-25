.pragma library

// Pairing guard: a device that calls itself "AirPods" must not be able to
// type on the keyboard. Names are free text chosen by the device, so they
// never decide trust on their own (P115).

// Bluetooth profiles that can send key presses or pointer moves:
// HID over classic Bluetooth (0x1124) and over Bluetooth LE (0x1812).
var inputUuids = ["00001124-0000-1000-8000-00805f9b34fb", "00001812-0000-1000-8000-00805f9b34fb"];

// A device shown as anything but an input device (headset, speaker, phone…)
// that also exposes a keyboard/mouse profile is refused: it was not what the
// user agreed to pair. Real keyboards and mice keep working.
function refused(family, uuids) {
    if (family === "keyboard" || family === "pointer" || family === "gaming")
        return false;
    return !!uuids && uuids.some(u => inputUuids.indexOf(String(u).toLowerCase()) >= 0);
}

// busctl --json=short get-property … UUIDs  →  {"type":"as","data":[…]}
function parseUuids(text) {
    try {
        const j = JSON.parse(text);
        if (!j || j.type !== "as" || !Array.isArray(j.data))
            return null;
        return j.data.slice(0, 64).map(u => String(u).toLowerCase());
    } catch (e) {
        return null;
    }
}
