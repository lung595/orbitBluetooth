.pragma library
.import "../common/Address.js" as Address

// Reading a candidate's signal strength from BlueZ (Device1.RSSI), which
// Quickshell does not expose. Pure logic, free of QML so it can be tested
// (tests/signal.test.js, with a fake busctl).

// The one command a read runs: busctl takes the path as data, after "--", and
// only an object path BlueZ could have given is accepted. null otherwise.
function command(path) {
    if (!Address.isDevicePath(path))
        return null;
    return ["busctl", "--json=short", "get-property", "--", "org.bluez", path, "org.bluez.Device1", "RSSI"];
}

// busctl's exit code and output -> dBm, or undefined for "no reading":
// BlueZ has no RSSI outside a discovery ("No such property", exit 1), the
// service may be gone, or the answer may be anything but an int16 below 0
//   {"type":"n","data":-62}
function parse(code, text) {
    if (code !== 0)
        return undefined;
    try {
        const j = JSON.parse(text);
        if (!j || j.type !== "n" || typeof j.data !== "number" || !isFinite(j.data) || j.data >= 0)
            return undefined;
        return j.data;
    } catch (e) {
        return undefined;
    }
}
