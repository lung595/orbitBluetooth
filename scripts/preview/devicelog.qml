import QtQuick
import Quickshell.Bluetooth

// Bench scene for the daemon's device bookkeeping (DeviceLog: connection
// times, battery samples, UPower facts), on the test stubs, no picture.
// Run: qml -I imports -I ../../tests/qml/stubs devicelog.qml -- <mode>
// Modes: "rest" keeps three connected devices still; "connect-loop" connects
// and disconnects a headset every 500 ms and moves its battery while it is on.
// A revision without DeviceLog.qml runs the same loop with nothing listening,
// which bounds the cost of the bookkeeping from above.
Item {
    id: scene

    readonly property bool loop: Qt.application.arguments.includes("connect-loop")
    readonly property Component deviceType: Qt.createComponent("../../tests/qml/Device.qml")
    property var headset: null

    function device(address, name, connected) {
        return deviceType.createObject(scene, {
            "address": address,
            "name": name,
            "deviceName": name,
            "paired": true,
            "connected": connected
        });
    }

    Component.onCompleted: {
        headset = device("AA:BB:CC:00:00:01", "Headset", true);
        Bluetooth.list = Bluetooth.devices = [headset, device("AA:BB:CC:00:00:02", "Mouse", true), device("AA:BB:CC:00:00:03", "Speaker", true)];
        log.active = true;
    }

    Loader {
        id: log
        active: false
        source: "../../components/common/DeviceLog.qml"
    }

    Timer {
        interval: 500
        running: scene.loop && scene.headset !== null
        repeat: true
        onTriggered: {
            const h = scene.headset;
            h.connected = !h.connected;
            if (h.connected)
                h.battery = h.battery > 0.2 ? h.battery - 0.05 : 0.9;
        }
    }
}
