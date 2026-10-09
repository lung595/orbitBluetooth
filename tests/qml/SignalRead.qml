import QtQuick

// Test stand-in for components/pairing/SignalRead.qml: same contract, but the
// signal comes from the fake device's `rssi` instead of a busctl call
// (the busctl side is covered by tests/signal.test.js).
Item {
    property var log: []

    function read(device, done) {
        log = log.concat([device ? device.name : ""]);
        const rssi = device ? device.rssi : undefined;
        Qt.callLater(() => done(rssi));
    }
}
