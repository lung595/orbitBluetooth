pragma Singleton
import QtQuick

QtObject {
    property var adapter: QtObject {
        property bool discovering: false
    }
    property bool enabled: true
    property bool available: true
    property bool discovering: false
    property var log: []
    function pairDevice(d, cb) {
        log.push("pair " + d.name);
        Qt.callLater(() => {
            d.paired = true;
            cb({});
        });
    }
    function connectDeviceWithTrust(d) {
        log.push("connect " + d.name);
        Qt.callLater(() => d.connected = true);
    }
}
