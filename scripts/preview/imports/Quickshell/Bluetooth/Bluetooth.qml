pragma Singleton
import QtQuick

// Made-up Bluetooth registry for the delay bench: six connected devices
QtObject {
    id: bt
    readonly property var devices: QtObject {
        property var values: {
            const out = [];
            for (let i = 1; i <= 6; i++)
                out.push(dev.createObject(bt, {
                    "address": "02:00:00:00:30:0" + i,
                    "name": "Fictional Speaker " + i
                }));
            return out;
        }
    }
    property Component dev: Component {
        QtObject {
            property string address
            property string name
            property bool connected: true
            function disconnect() {
                connected = false;
            }
        }
    }
}
