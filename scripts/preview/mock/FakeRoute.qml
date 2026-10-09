import QtQuick

// What the daemon's AudioRoute gives the card, made up: the headset
// (02:00:00:00:10:06) at 62 % with this PC at 85 %; with `sharing` set, the
// headset and other made-up outputs listen together (D277), each at its own
// level, over this PC's shared one.
QtObject {
    id: fake
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
    // What the group chooser asks of the made-up machine: the wired outputs
    // plugged in (node names), the connected devices that have no sound output
    // yet, the ones on their call profile, and a refusal that start and add
    // answer instead of doing it (null: they do it)
    property var wired: []
    readonly property var silent: ["00:11:22:33:44:55", "98:7A:14:22:C1:0E"]
    property var inCall: []
    property var refusal: null
    component Level: QtObject {
        property real volume: 0.5
        property bool muted: false
    }
    component Node: QtObject {
        property string name: ""
        property Level audio: Level {}
    }
    // A wired output as PipeWire describes it (D298): a description and the
    // properties of its card
    component WiredNode: Node {
        property string description: ""
        property var properties: ({})
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
    // Made-up wired outputs, by the node name a group's member is: a USB
    // interface, a screen on HDMI and speakers on the jack
    readonly property var _wired: ({
            "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo": usbDac,
            "alsa_output.pci-0000_00_1f.3.hdmi-stereo": screen,
            "alsa_output.pci-0000_00_1f.3.analog-stereo": jack
        })
    readonly property WiredNode usbDac: WiredNode {
        name: "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo"
        description: "Fictional Audio DAC"
        properties: ({
                "device.bus": "usb"
            })
        audio: Level {
            volume: 0.4
        }
    }
    readonly property WiredNode screen: WiredNode {
        name: "alsa_output.pci-0000_00_1f.3.hdmi-stereo"
        description: "Fictional Monitor"
        audio: Level {
            volume: 0.7
        }
    }
    readonly property WiredNode jack: WiredNode {
        name: "alsa_output.pci-0000_00_1f.3.analog-stereo"
        description: "Fictional Speakers"
        properties: ({
                "device.form_factor": "speaker"
            })
        audio: Level {
            volume: 0.55
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
        // As the daemon's session: it tells when it ended or a member left
        signal ended(string why, string address)
        signal memberLeft(string address)
        readonly property var route: fake
        readonly property var members: fake.sharing
        readonly property bool active: members.length >= 2
        // The first member is the output in use: the one whose sound is copied
        readonly property string source: active ? members[0] : ""
        function nameOf(address) {
            if (fake._wired[address])
                return fake._wired[address].description;
            const d = fake.known(address);
            return d && d.device ? d.device.name : "";
        }
        readonly property var sharedNode: fake.shared
        readonly property var sharedNodes: [fake.shared, fake.copyOne]
        function isMember(address) {
            return members.indexOf(address) >= 0;
        }
        function memberNode(address) {
            return address === "02:00:00:00:10:06" ? fake.headset.sink : fake._others[address] || fake._wired[address] || null;
        }
        // The drag's rules of the real session, as far as the scene reads them:
        // an address the route does not know is a device that is not connected;
        // a wired output of the group can be dropped on
        function relevant(a, b) {
            return !!fake.known(a) && (!!fake.known(b) || !!fake._wired[b]);
        }
        // As the real session: a member leaves, and with fewer than two left
        // the group ends. null when it was done.
        function remove(address) {
            if (!isMember(address))
                return {
                    "why": "not-member",
                    "address": address
                };
            const next = fake.sharing.filter(a => a !== address);
            fake.sharing = next.length < 2 ? [] : next;
            return null;
        }
        // As the real session: starts with the two, or adds the one not in yet
        function join(a, b) {
            const r = dropCheck(a, b);
            if (r)
                return r;
            fake.sharing = fake.sharing.length ? fake.sharing.concat(isMember(a) ? [b] : [a]) : [a, b];
            return null;
        }
        function dropCheck(a, b) {
            return fake.known(a) ? null : {
                "why": "not-connected",
                "address": a
            };
        }
        // The group chooser: why an output cannot take part, null when it can
        function memberCheck(who) {
            if (fake.wired.indexOf(who) >= 0)
                return null;
            const why = fake.silent.indexOf(who) >= 0 ? "no-audio" : !fake.known(who) ? "not-connected" : fake.inCall.indexOf(who) >= 0 ? "in-call" : "";
            return why ? {
                "why": why,
                "address": who
            } : null;
        }
        // The ghost group (OrbitGhost), as the real session answers it: a list can start
        // when each member is an output the route knows or a wired one (by its node name)
        function check(list) {
            const unknown = list.find(a => !/^alsa_output\./.test(a) && fake.wired.indexOf(a) < 0 && !fake.known(a));
            if (list.length < 2)
                return {
                    "why": "too-few",
                    "address": ""
                };
            return unknown ? {
                "why": "not-connected",
                "address": unknown
            } : null;
        }
        // A test can force a refusal; otherwise the session's own check decides
        function start(list) {
            const r = fake.refusal || check(list);
            if (!r)
                fake.sharing = list.slice();
            return r;
        }
        function add(list) {
            if (!fake.refusal)
                fake.sharing = fake.sharing.concat(list);
            return fake.refusal;
        }
        // The groups the user turned down, by key (kept as long as the route)
        property var declined: ({})
        function decline(key) {
            declined = Object.assign({}, declined, {
                [key]: true
            });
        }
        function isDeclined(key) {
            return declined[key] === true;
        }
    }
    function known(address) {
        if (address === "02:00:00:00:10:06")
            return headset;
        const n = String(address).slice(-1);
        return _others[address] ? {
            "address": address,
            "absolute": 1,
            "sink": _others[address],
            "device": {
                "address": address,
                "name": "Speaker " + n,
                "icon": "audio-speakers"
            }
        } : null;
    }
    // The same rules as the real route's (Route.levelNodes, tested in
    // tests/volume.test.js): the shared PC half is on every member's copy
    function writeLevel(node, level) {
        (node === shared ? together.sharedNodes : [node]).forEach(n => {
            n.audio.volume = level;
            n.audio.muted = false;
        });
    }
    function writeMuted(node, muted) {
        (node === shared ? together.sharedNodes : [node]).forEach(n => n.audio.muted = muted);
    }
    // The real route's writeLevels: a level of its own for each node, and what
    // it was asked to play as a tick
    property var ticked: []
    function writeLevels(nodes, levels, before, after) {
        nodes.forEach((n, i) => {
            n.audio.muted = false;
            n.audio.volume = levels[i];
        });
        ticked = ticked.concat([
            {
                "nodes": nodes.map(n => n.name),
                "before": before,
                "after": after
            }
        ]);
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
    // The real route's ownNode and touch (NAK-9): a wired output's node, else
    // the Bluetooth device's own-level node
    property string touched: ""
    function touch(address) {
        touched = address;
    }
    function ownNode(address) {
        const node = _wired[address] || deviceNode(known(address));
        return node && node.audio ? node : null;
    }
    function mainPart(address) {
        return "device";
    }
    function stepFor(dir, level) {
        return 5;
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
    // The Bluetooth devices that play sound, and the one in use (AudioRoute's
    // audioDevices() and current), for a test to set: none at first
    property var audio: []
    property var current: null
    function audioDevices() {
        return audio;
    }
}
