import QtQuick

// A BlueZ device as Quickshell exposes it, reduced to what the pop-up reads
QtObject {
    property string address
    property string name
    property string deviceName: name
    property string icon
    property bool paired: false
    property bool bonded: false
    property bool connected: false
    property bool pairing: false
    property bool batteryAvailable: connected
    property real battery: 0.8
    property bool blocked: false
    function disconnect() { connected = false }
    function cancelPair() {}
}
