import QtQuick

// A BlueZ device as Quickshell exposes it, reduced to what the pop-up reads
QtObject {
    property string address
    property string name
    // The name the device reports itself: a rename (alias) never changes it
    property string deviceName
    property string icon
    property bool paired: false
    property bool bonded: false
    property bool connected: false
    property bool pairing: false
    property bool batteryAvailable: connected
    property real battery: 0.8
    property bool blocked: false
    property bool trusted: false
    property bool forgotten: false
    // Signal strength in dBm as the fake SignalRead reads it, undefined = no reading
    property var rssi: undefined
    // Bluetooth profiles the device exposes (BlueZ Device1.UUIDs)
    property var uuids: ["0000110b-0000-1000-8000-00805f9b34fb"]
    // BlueZ reports a disconnection a moment after it was asked for: a test
    // can hold `connected` until it lets go
    property bool lingers: false
    property int disconnects: 0
    function disconnect() {
        disconnects++;
        if (!lingers)
            connected = false;
    }
    function forget() {
        forgotten = true;
        paired = false;
    }
    function cancelPair() {
    }
}
