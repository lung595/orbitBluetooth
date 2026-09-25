pragma Singleton
import QtQuick
QtObject {
    property var adapter: null
    property bool available: true
    property bool enabled: true
    property bool discovering: false
    function connectDeviceWithTrust(d) {}
    function pairDevice(d, cb) {}
    function setBluetoothEnabled(v) {}
    function toggleBluetooth() {}
}
