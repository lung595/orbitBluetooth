import QtQuick

// The made-up headset of the pop-up's demo (dms ipc call orbitBluetooth
// newDeviceDemo): it has the properties and methods of a BlueZ device that
// the sheet reads, and nothing behind them. Nothing is paired or saved.
QtObject {
    property string address: "demo"
    property string name: "WH-1000XM6"
    property string deviceName: "WH-1000XM6"
    property string icon: "audio-headphones"
    property bool paired: false
    property bool bonded: false
    property bool connected: false
    property bool pairing: false
    property bool batteryAvailable: connected
    property real battery: 0.8
    function disconnect() {
        connected = false;
    }
    function cancelPair() {
    }
}
