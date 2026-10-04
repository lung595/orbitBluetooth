.pragma library

// The shapes of a Bluetooth address, and of the BlueZ object path built from
// it, in one place. Everything that reaches a command goes through here first
// (value 11). Pure logic, tested in tests/anc.test.js.

// "AA:BB:CC:DD:EE:FF" or "AA_BB_CC_DD_EE_FF", any case -> "AA_BB_CC_DD_EE_FF",
// the way BlueZ object paths and PipeWire node names spell it; "" if it is
// not an address
function key(address) {
    const k = String(address || "").replace(/:/g, "_").toUpperCase();
    return /^([0-9A-F]{2}_){5}[0-9A-F]{2}$/.test(k) ? k : "";
}

// The same address with colons, "AA:BB:CC:DD:EE:FF", or ""
function colon(address) {
    return key(address).replace(/_/g, ":");
}

// The first address inside a text (a BlueZ object path, a HID_UNIQ line),
// with colons, or ""
function find(text) {
    const m = /[0-9a-f]{2}([:_-])[0-9a-f]{2}(\1[0-9a-f]{2}){4}/i.exec(String(text || ""));
    return m ? colon(m[0].replace(/-/g, "_")) : "";
}

// The object path BlueZ gives a device: /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF.
// The only form of path ever handed to busctl.
function isDevicePath(path) {
    return /^\/org\/bluez\/hci[0-9]{1,3}\/dev_[0-9A-F]{2}(_[0-9A-F]{2}){5}$/.test(String(path || ""));
}
