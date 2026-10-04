import QtQuick

// What the daemon's AudioRoute gives the card, made up: the headset
// (02:00:00:00:10:06) at 62 % with this PC at 85 %.
QtObject {
    // The device the open card is on
    property var focusDevice: null
    // True: the headset has no level of its own and follows the PC volume
    property bool follow: false

    readonly property var headset: ({
            "device": focusDevice,
            "absolute": follow ? 0 : 1,
            "sink": {
                "name": "bluez_output.02_00_00_00_10_06.1",
                "audio": {
                    "volume": follow ? 0.85 : 0.62,
                    "muted": false
                }
            },
            "pc": follow ? null : {
                "audio": {
                    "volume": 0.85,
                    "muted": false
                }
            }
        })

    function find(address) {
        return address === "02:00:00:00:10:06" ? headset : null;
    }
    function deviceNode(dev) {
        return dev && dev.absolute === 1 ? dev.sink : null;
    }
    function pcNode(dev) {
        return dev ? (dev.pc || (dev.absolute === 1 ? null : dev.sink)) : null;
    }
    function mainPart(address) {
        return "device";
    }
    function stepNode(node, dir) {
    }
    function setLevel(which, arg, address) {
        return "";
    }
    function toggleMute(address) {
        return "pc";
    }
}
