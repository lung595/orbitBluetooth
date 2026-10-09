import QtQuick
import QtQuick.Window
import "../../components/together"
import "../../components/volume/Route.js" as Route

// Offscreen bench of the Listen together session itself (TogetherSession, its
// copies and its graph reader), with no view: the preview scenes draw the
// group from a made-up session, so they never run this code. The processes
// are the preview's stand-ins (nothing runs). Made-up devices and outputs.
// Never grabs, never quits: it runs until the bench stops it.
// Usage: QT_QPA_PLATFORM=offscreen qml -I imports together.qml -- <mode> /dev/null
// Modes: rest (a group of three formed once, then nothing), form2 / form4 (a
//        group of two or four formed at 0 s and ended at 1.5 s, every 3 s),
//        join (a group of two, a third member joins at 0 s and leaves at
//        1.5 s, every 3 s), drag (a wired source and two Bluetooth members,
//        the group's level written at 60 Hz, up then down over 4 s, as the
//        gauge's drag writes it through AudioRoute)
Window {
    id: win
    readonly property var args: Qt.application.arguments
    readonly property string mode: args[args.length - 2]
    width: 64
    height: 64
    visible: true

    readonly property var bt: ["02:00:00:00:10:01", "02:00:00:00:10:02", "02:00:00:00:10:03", "02:00:00:00:10:04"]
    readonly property string wired: "alsa_output.usb-Fictional_Audio-DAC-00.analog-stereo"

    QtObject {
        id: route
        property var devices: ({})
        property var wired: ({})
        property var filters: ({})
        function known(address) {
            return devices[address] || null;
        }
        function wiredSink(name) {
            return wired[name] || null;
        }
        function wiredFilter(name) {
            return filters[name] || null;
        }
        function deviceNode(device) {
            return null;
        }
        function pcNode(device) {
            return device.pc || device.sink;
        }
    }
    TogetherSession {
        id: session
        route: route
    }

    function key(address) {
        return address.replace(/:/g, "_");
    }
    Component.onCompleted: {
        const devices = {};
        for (const a of bt)
            devices[a] = {
                "name": "Device " + a.slice(-2),
                "connected": true,
                "sink": {
                    "name": "bluez_output." + key(a) + ".1",
                    "properties": {
                        "api.bluez5.profile": "a2dp-sink"
                    }
                },
                "pc": {
                    "name": "orbit_pc_" + key(a),
                    "audio": {
                        "volume": 0.6,
                        "muted": false
                    }
                }
            };
        route.devices = devices;
        const w = {};
        w[wired] = {
            "name": wired,
            "description": "Fictional DAC",
            "nickname": "",
            "audio": {
                "volume": 1,
                "muted": false
            }
        };
        route.wired = w;
        if (mode === "rest")
            session.start(bt.slice(0, 3));
        else if (mode === "join")
            session.start(bt.slice(0, 2));
        else if (mode === "drag")
            session.start([wired, bt[0], bt[1]]);
    }

    property int ticks: 0
    // The action of form2 / form4 / join, every 3 s: on at 0 s, off at 1.5 s
    Timer {
        interval: 1500
        repeat: true
        running: ["form2", "form4", "join"].indexOf(win.mode) >= 0
        onTriggered: {
            const on = win.ticks++ % 2 === 0;
            if (win.mode === "join") {
                if (on)
                    session.add([win.bt[2]]);
                else
                    session.remove(win.bt[2]);
            } else if (on) {
                session.start(win.bt.slice(0, win.mode === "form4" ? 4 : 2));
            } else {
                session.end("ended", "");
            }
        }
    }
    property real sweep: 0
    Timer {
        interval: 16
        repeat: true
        running: win.mode === "drag" && session.active
        onTriggered: {
            win.sweep = (win.sweep + 16 / 2000) % 2;
            const v = win.sweep < 1 ? win.sweep : 2 - win.sweep;
            Route.writeLevel(session.sharedNodes, session.sharedNode, v);
        }
    }
    Timer {
        interval: 5000
        running: true
        onTriggered: console.warn("together bench:", win.mode, "members", session.members.length, "shared", session.sharedNodes.length, "ticks", win.ticks)
    }
}
