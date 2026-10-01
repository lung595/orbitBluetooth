pragma Singleton
import QtQuick
QtObject {
    property var adapter: QtObject { property bool discovering: false; property bool enabled: true }
    property bool enabled: true
    property var log: []
    property bool failPair: false
    function pairDevice(d, cb) {
        log.push("pair " + d.name);
        Qt.callLater(() => { if (!failPair) d.paired = true; cb(failPair ? { error: "rejected" } : {}); });
    }
    function connectDeviceWithTrust(d) {
        log.push("connect " + d.name);
        Qt.callLater(() => d.connected = true);
    }
}
