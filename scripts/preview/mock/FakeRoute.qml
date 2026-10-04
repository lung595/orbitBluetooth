import QtQuick

// What the daemon's AudioRoute gives the card, made up: the headset
// (02:00:00:00:10:06) at 62 % with this PC at 85 %; with `sharing` set, the
// headset and other made-up outputs listen together (D277), each at its own
// level, over this PC's shared one.
QtObject {
    id: route
    // The device the open card is on
    property var focusDevice: null
    // True: the headset has no level of its own and follows the PC volume
    property bool follow: false

    readonly property var headset: ({
            "address": "02:00:00:00:10:06",
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
                "name": "orbit_pc_filter",
                "audio": {
                    "volume": 0.85,
                    "muted": false
                }
            }
        })

    // Listening together: the addresses sharing the sound, in the order they
    // joined ([] for none). The headset's own is its sink; the others' are
    // made up here, with levels of their own
    property var sharing: []
    component Level: QtObject {
        property real volume: 0.5
        property bool muted: false
    }
    component Node: QtObject {
        property string name: ""
        property Level audio: Level {}
    }
    readonly property var _others: ({
            "02:00:00:00:20:01": otherOne,
            "02:00:00:00:20:02": otherTwo,
            "02:00:00:00:20:03": otherThree
        })
    readonly property Node otherOne: Node {
        name: "bluez_output.02_00_00_00_20_01.1"
        audio: Level {
            volume: 0.3
        }
    }
    readonly property Node otherTwo: Node {
        name: "bluez_output.02_00_00_00_20_02.1"
        audio: Level {
            volume: 0.8
        }
    }
    readonly property Node otherThree: Node {
        name: "bluez_output.02_00_00_00_20_03.1"
        audio: Level {
            volume: 0.5
            muted: true
        }
    }
    // This PC's level shared by the outputs: the source's filter node, and
    // the copy each member holds
    readonly property Node shared: Node {
        name: "orbit_pc_filter"
        audio: Level {
            volume: 0.85
        }
    }
    readonly property Node copyOne: Node {
        name: "orbit_pc_filter_copy_1"
        audio: Level {
            volume: 0.85
        }
    }
    readonly property var together: QtObject {
        readonly property var members: route.sharing
        readonly property bool active: members.length >= 2
        readonly property var sharedNode: route.shared
        readonly property var sharedNodes: [route.shared, route.copyOne]
        function isMember(address) {
            return members.indexOf(address) >= 0;
        }
        function memberNode(address) {
            return address === "02:00:00:00:10:06" ? route.headset.sink : route._others[address] || null;
        }
    }
    function known(address) {
        if (address === "02:00:00:00:10:06")
            return headset;
        const n = String(address).slice(-1);
        return _others[address] ? {
            "address": address,
            "device": {
                "address": address,
                "name": "Speaker " + n,
                "icon": "audio-speakers"
            }
        } : null;
    }
    // The nodes a level written to `node` reaches: the shared PC half is on
    // every member's copy
    function levelNodes(node) {
        return node === shared ? together.sharedNodes : [node];
    }
    function writeLevel(node, level) {
        levelNodes(node).forEach(n => {
            n.audio.volume = level;
            n.audio.muted = false;
        });
    }
    function writeMuted(node, muted) {
        levelNodes(node).forEach(n => n.audio.muted = muted);
    }

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
        writeLevel(node, Math.max(0, Math.min(1, node.audio.volume + dir * 0.05)));
    }
    function setLevel(which, arg, address) {
        return "";
    }
    function toggleMute(address) {
        return "pc";
    }
}
