import QtQuick
import "components/volume"
import "components/together"

// Test of the arcs of a wired member in TwoLevels (D298): beside a Bluetooth
// device it is drawn by the kind of its connection (usb, hdmi, analog) and
// never by a Bluetooth picture, named as the session names it (one clean
// line), at the level of its own sink. Made-up outputs only. Run with
// tests/qml/run.sh.
Item {
    id: h

    readonly property string phones: "AA:BB:CC:DD:EE:01"
    readonly property string usbOut: "alsa_output.usb-Acme_Studio_2x2-00.analog-stereo"
    readonly property string hdmiOut: "alsa_output.pci-0000_00_1f.3.hdmi-stereo"
    readonly property string jackOut: "alsa_output.pci-0000_00_1f.3.analog-stereo"

    // A sink as Quickshell holds it, cut down to what is read
    component Sink: QtObject {
        id: sink
        property string name: ""
        property string description: ""
        property string nickname: ""
        property var properties: ({})
        property real level: 0.5
        property QtObject audio: QtObject {
            property real volume: sink.level
            property bool muted: false
        }
    }
    Sink {
        id: phonesSink
        name: "bluez_output.AA_BB_CC_DD_EE_01.1"
        level: 0.4
    }
    Sink {
        id: usbSink
        name: h.usbOut
        description: "Acme Studio\u0007 2x2"
        properties: ({
                "device.bus": "usb"
            })
        level: 0.7
    }
    Sink {
        id: hdmiSink
        name: h.hdmiOut
        description: "Built-in HDMI"
        properties: ({
                "device.bus": "pci"
            })
        level: 0.9
    }
    Sink {
        id: jackSink
        name: h.jackOut
        description: "Built-in Audio"
        level: 0.2
    }

    QtObject {
        id: route
        readonly property var together: session
        property var devices: ({
                [h.phones]: {
                    "address": h.phones,
                    "connected": true,
                    "device": {
                        "address": h.phones,
                        "name": "Headset",
                        "icon": "audio-headphones"
                    },
                    "sink": phonesSink
                }
            })
        function known(address) {
            return devices[address] || null;
        }
        function wiredSink(name) {
            return [usbSink, hdmiSink, jackSink].find(n => n.name === name) || null;
        }
        function wiredFilter(name) {
            return null;
        }
        function deviceNode(dev) {
            return null;
        }
        function pcNode(dev) {
            return dev ? dev.sink : null;
        }
        // What the gestures pass on: the node and whether the level is the group's
        property var writes: []
        function writeLevel(node, level, group) {
            writes.push({
                "node": node,
                "group": group
            });
        }
        function writeMuted(node, muted) {
        }
        function stepNode(node, dir, group) {
            writes.push({
                "node": node,
                "group": group
            });
        }
        function touch(address) {
        }
        function touchLevel(part, dev) {
        }
    }
    TogetherSession {
        id: session
        route: route
    }
    TwoLevels {
        id: levels
        route: route
        dev: route.known(h.phones)
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    Component.onCompleted: {
        check("start with a headset, a USB interface and the HDMI output", session.start([h.phones, h.usbOut, h.hdmiOut]), null);
        check("split, in the order they joined", [levels.split, levels.members.map(m => m.part), levels.members.map(m => m.address)], [true, ["m0", "m1", "m2"], [h.phones, h.usbOut, h.hdmiOut]]);
        check("each is at the level of its own output", levels.members.map(m => m.level), [0.4, 0.7, 0.9]);
        check("a wired output is drawn by its connection, never by a Bluetooth picture", levels.members.map(m => m.icon), ["headphones", "usb", "settings_input_hdmi"]);
        check("and named as the session names it, one clean line", levels.members.map(m => m.label), ["Headset", "Acme Studio 2x2", "Built-in HDMI"]);

        // One whose properties say nothing is told by its name
        check("the sound card's jack is analog, by its name", session.add([h.jackOut]), null);
        check("it has the analog picture, and the group still shows four arcs", [levels.members.length, levels.members[3].icon, levels.members[3].label], [4, "cable", "Built-in Audio"]);
        session.remove(h.jackOut);

        // Only the group's general level (the shared PC half) sounds on every member
        route.writes = [];
        levels.setLevel("pc", 0.3);
        levels.stepLevel("pc", 1);
        levels.setLevel("m1", 0.3);
        levels.stepLevel("m1", 1);
        check("in a group the general level is written as the group's, by drag and by wheel", route.writes.slice(0, 2).map(w => w.group), [true, true]);
        check("a member's own level is not", route.writes.slice(2).map(w => w.group), [false, false]);
        route.writes = [];
        session.end("test");
        levels.setLevel("pc", 0.3);
        levels.stepLevel("pc", 1);
        check("outside a group nothing is the group's", route.writes.map(w => w.group), [false, false]);

        // Not Bluetooth: the device card of a wired output is not split by this
        check("a wired output is not a Bluetooth device, so no device to split on", route.known(h.usbOut), null);
        print(h.failures ? h.failures + " failure(s)" : "all passed");
        Qt.exit(h.failures ? 1 : 0);
    }
}
