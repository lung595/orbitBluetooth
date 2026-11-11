import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "components/volume"
import "components/together"
import "components/volume/Route.js" as Route
import "components/together/Together.js" as Together
import "diagnostics/Log.js" as Log

// Test of the watch over Orbit's loopback processes: `pipewire -c`, unlike
// pw-loopback, keeps running when its loopback is destroyed (an output
// unplugged, PipeWire restarted), so a node that was there and has been
// missing for 2 s while its process runs is taken as an exit. The PC-level
// filter (RouteDevice) logs ORB-E003 and starts again; a copy or the wired
// filter of Listen together (TogetherLink) is lost, once. A node never seen,
// or back within 2 s, changes nothing. The nodes are the mock Pipewire's
// extraSinks, the processes the stand-in of Quickshell.Io. Made-up addresses
// only. Run with tests/qml/run.sh.
Item {
    id: h

    readonly property string mac: "AA:BB:CC:DD:EE:01"
    readonly property string other: "AA:BB:CC:DD:EE:02"
    readonly property string wired: "alsa_output.usb-Acme_Demo_Headset-00.analog-stereo"

    Component {
        id: fakeNode
        QtObject {
            required property string name
            property bool isSink: true
            property bool isStream: false
            readonly property bool ready: true
            readonly property QtObject audio: QtObject {
                property real volume: 1
                property bool muted: false
            }
        }
    }
    readonly property QtObject deviceSink: fakeNode.createObject(h, {
        "name": "bluez_output.AA_BB_CC_DD_EE_01.1"
    })
    readonly property QtObject pcNode: fakeNode.createObject(h, {
        "name": Route.virtualName(mac)
    })
    readonly property var tap: ({
            "member": other,
            "capture": Route.virtualName(mac),
            "playback": "bluez_output.AA_BB_CC_DD_EE_02.1"
        })
    readonly property QtObject copyNode: fakeNode.createObject(h, {
        "name": Together.nodeOf(Together.args(tap, 0)),
        "isSink": false,
        "isStream": true
    })
    readonly property QtObject wiredNode: fakeNode.createObject(h, {
        "name": Route.wiredFilterName(wired)
    })

    RouteDevice {
        id: dev
        device: ({
                "address": h.mac,
                "deviceName": "Buds",
                "connected": true,
                "dbusPath": ""
            })
    }
    property var lost: []
    TogetherLink {
        id: link
        onLost: key => h.lost = h.lost.concat([key])
    }

    function filterProcess() {
        return ProcessLog.live.find(p => p.command.length > 4 && p.command[4].indexOf("node.name=" + Route.virtualName(h.mac) + " ") >= 0) || null;
    }
    function linkProcess(key) {
        const name = key === Together.FILTER_KEY ? Route.wiredFilterName(h.wired) : copyNode.name;
        return ProcessLog.live.find(p => Together.nodeOf(p.command) === name) || null;
    }
    property var errors: []
    function e003() {
        return h.errors.filter(l => /ORB-E003 tool=pw_loopback/.test(l));
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // --- The PC-level filter ----------------------------------------------------------------
    function step1() {
        check("the node a loopback makes is read from its capture end", [Together.nodeOf(Route.filterArgs(h.mac, deviceSink.name, "Buds")), Together.nodeOf(Route.wiredFilterArgs(h.wired, "")), Together.nodeOf(null), Together.nodeOf(["bash"])], [Route.virtualName(h.mac), Route.wiredFilterName(h.wired), "", ""]);
        Pipewire.extraSinks = [deviceSink];
        dev.absolute = 1;
        check("a device with its own volume: the filter's process runs", [!!filterProcess(), filterProcess() && filterProcess().running], [true, true]);
        Pipewire.extraSinks = [deviceSink, pcNode];
        check("its filter shows up", dev.pc === pcNode, true);
        // Gone for less than 2 s: a node list being rebuilt, nothing more
        Pipewire.extraSinks = [deviceSink];
        wait(500);
    }
    function step2() {
        Pipewire.extraSinks = [deviceSink, pcNode];
        wait(2200);
    }
    function step3() {
        check("back within 2 s: still running, nothing logged", [filterProcess().running, e003().length], [true, 0]);
        // PipeWire restarted: the device's sink came back, the filter did not
        Pipewire.extraSinks = [deviceSink];
        wait(2300);
    }
    function step4() {
        check("missing for 2 s while running: stopped and logged", [filterProcess() ? filterProcess().running : false, e003()], [false, ["ORB-E003 tool=pw_loopback code=-1"]]);
        wait(1200);
    }
    function step5() {
        check("a moment later it starts again by itself", [!!filterProcess() && filterProcess().running], [true]);
        // The new one never makes its node: it is left alone, no loop
        wait(2500);
    }
    function step6() {
        check("a filter never seen is never stopped", [filterProcess().running, e003().length], [true, 1]);
        Pipewire.extraSinks = [deviceSink, pcNode];
        dev.absolute = 0;
        check("not wanted: stopped", filterProcess() ? filterProcess().running : false, false);
        Pipewire.extraSinks = [deviceSink];
        wait(2300);
    }
    function step7() {
        check("a filter not running is not watched", e003().length, 1);

        // --- Listen together ------------------------------------------------------------------
        Pipewire.extraSinks = [];
        link.copies = [
            {
                "key": Together.FILTER_KEY,
                "command": Route.wiredFilterArgs(h.wired, "")
            },
            {
                "key": h.other,
                "command": Together.args(h.tap, 0)
            }
        ];
        check("the copy and the wired filter run", [linkProcess(h.other).running, linkProcess(Together.FILTER_KEY).running], [true, true]);
        Pipewire.extraSinks = [copyNode];
        Pipewire.extraSinks = [];
        wait(2300);
    }
    function step8() {
        check("the copy's node gone for 2 s: it is lost, and stopped", [h.lost, linkProcess(h.other).running], [[h.other], false]);
        check("the wired filter, never seen, runs on", linkProcess(Together.FILTER_KEY).running, true);
        linkProcess(h.other).exited(0);
        check("its exit afterwards is not lost twice", h.lost, [h.other]);
        Pipewire.extraSinks = [wiredNode];
        Pipewire.extraSinks = [];
        wait(2300);
    }
    function step9() {
        check("the wired filter's node gone for 2 s: lost too", h.lost, [h.other, Together.FILTER_KEY]);
        link.copies = [];
        check("nothing is left running", ProcessLog.live.filter(p => p.command[0] === "bash" && p.running && Together.nodeOf(p.command) !== Route.virtualName(h.mac)).length, 0);
    }

    property var steps: [step1, step2, step3, step4, step5, step6, step7, step8, step9]
    property int next: 0
    property double holdUntil: 0
    function wait(ms) {
        holdUntil = Date.now() + ms;
    }
    Timer {
        id: stepper
        // 1 ms: a 0 ms timer never fires under the offscreen test platform
        interval: 1
        repeat: true
        onTriggered: {
            if (Date.now() < h.holdUntil)
                return;
            if (h.next >= h.steps.length) {
                stepper.stop();
                print(h.failures ? h.failures + " failure(s)" : "all passed");
                Qt.exit(h.failures ? 1 : 0);
                return;
            }
            h.steps[h.next++]();
        }
    }
    Component.onCompleted: {
        Log.setSink({
            "error": line => h.errors = h.errors.concat([line.replace(/^\[[^\]]*\] /, "")]),
            "warn": line => {}
        });
        stepper.start();
    }
}
