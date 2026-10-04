import QtQuick
import Quickshell.Io
import "components/together"

// Test of Listen together (TogetherSession and its copies): who is in and who
// is not, which copies run for them (one per member that is copied to, a
// newcomer never cuts the others), what happens when a member is away, in a
// call or gone (D279: away keeps its place, only a Bluetooth disconnect or
// the user removes it), when the session ends, and the level the members
// share. The processes are the stand-in of Quickshell.Io listed in
// ProcessLog. Run with tests/qml/run.sh.
Item {
    id: h

    // A fake AudioRoute: devices by address, replaced as a whole when one changes
    QtObject {
        id: route
        property var devices: ({})
        function known(address) {
            return devices[address] || null;
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

    readonly property string a: "AA:BB:CC:DD:EE:01"
    readonly property string b: "AA:BB:CC:DD:EE:02"
    readonly property string c: "AA:BB:CC:DD:EE:03"
    readonly property string d: "AA:BB:CC:DD:EE:04"
    readonly property string e: "AA:BB:CC:DD:EE:05"

    function key(address) {
        return address.replace(/:/g, "_");
    }
    function sinkOf(address) {
        return {
            "name": "bluez_output." + key(address) + ".1",
            "properties": {
                "api.bluez5.profile": "a2dp-sink"
            }
        };
    }
    // A connected device with an output, and a PC-level filter when `level` is given
    function plug(address, level) {
        const next = Object.assign({}, route.devices);
        next[address] = {
            "name": "Device " + address.slice(-2),
            "connected": true,
            "sink": sinkOf(address),
            "pc": level === undefined ? null : {
                "name": "orbit_pc_" + key(address),
                "audio": {
                    "volume": level,
                    "muted": false
                }
            }
        };
        route.devices = next;
    }
    function patch(address, change) {
        const next = Object.assign({}, route.devices);
        next[address] = Object.assign({}, next[address], change);
        route.devices = next;
    }

    // The copies that run, as "member <- where it is copied from", by the last two digits
    function copies() {
        const out = [];
        for (const p of ProcessLog.live) {
            const member = /orbit_together_[0-9A-F_]*([0-9A-F]{2})_in/.exec(p.command[4])[1];
            const from = /target\.object=\S*?([0-9A-F]{2})(\.1)?\s/.exec(p.command[4])[1];
            out.push(member + "<-" + from + (/orbit_pc_/.test(p.command[4]) ? "pc" : ""));
        }
        return out.sort();
    }
    function live() {
        return ProcessLog.live.slice();
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    property var ends: []
    property var leaves: []
    Connections {
        target: session
        function onEnded(why, address) {
            h.ends = h.ends.concat([why + ":" + address.slice(-2)]);
        }
        function onMemberLeft(address) {
            h.leaves = h.leaves.concat([address.slice(-2)]);
        }
    }

    // The steps run one after another, a turn of the event loop apart: a member
    // that disconnects leaves once the update that told so is over
    property var steps: []
    property int next: 0
    Timer {
        id: stepper
        // 1 ms: a 0 ms timer never fires under the offscreen test platform
        interval: 1
        repeat: true
        running: false
        onTriggered: {
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
        steps = [step1, step2, step3, step4, step5, step6, step7, step8, step9];
        stepper.start();
    }

    function step1() {
        plug(a, 0.7);
        plug(b, 0.2);
        plug(c);
        plug(d);
        plug(e);

        check("nothing runs without a session", [session.active, copies()], [false, []]);
        check("a drop needs a session to join", session.joinCheck([b]).why, "no-session");
        check("a drop of two devices is fine", session.dropCheck(a, b), null);
        check("a device is not dropped onto itself", session.check([a, a]).why, "same");

        // --- Two members ---------------------------------------------------------
        check("start with two", session.start([a, b]), null);
        check("two members", [session.active, session.members], [true, [a, b]]);
        check("the source is the first with an output", session.source, a);
        check("one copy, to the other member, from the source's filter", copies(), ["02<-01pc"]);

        // --- A third and a fourth join without cutting the first copy -------------------
        const first = live()[0];
        check("a third joins by a drop onto any member", session.dropCheck(c, b), null);
        check("join", session.join(c, b), null);
        check("members in the order they joined", session.members, [a, b, c]);
        check("two copies now", copies(), ["02<-01pc", "03<-01pc"]);
        check("the first copy was not restarted", live().indexOf(first) >= 0, true);
        check("two outsiders do not make a drop", session.dropCheck(d, e).why, "outside");
        check("a member onto a member says already", session.dropCheck(a, c).why, "already");
        check("a fourth joins", session.join(d, a), null);
        check("three copies", copies(), ["02<-01pc", "03<-01pc", "04<-01pc"]);
        check("a fifth is refused: the cap", session.dropCheck(e, a).why, "too-many");
        check("the refusal does not change anything", [session.members.length, copies().length], [4, 3]);
    }

    function step2() {
        // --- A member whose output is away or in a call stays a member (D279) ----------
        patch(b, {
            "sink": null
        });
        check("its output went away: still a member", [session.members.length, session.active], [4, true]);
        check("its copy waits", copies(), ["03<-01pc", "04<-01pc"]);
        check("no note, no ending", [h.ends, h.leaves], [[], []]);
        patch(b, {
            "sink": sinkOf(b)
        });
        check("its output is back: the copy runs again", copies(), ["02<-01pc", "03<-01pc", "04<-01pc"]);
        patch(c, {
            "sink": {
                "name": "bluez_output." + key(c) + ".1",
                "properties": {
                    "api.bluez5.profile": "headset-head-unit"
                }
            }
        });
        check("in a call: a member, copy stopped", [session.members.length, copies()], [4, ["02<-01pc", "04<-01pc"]]);
        patch(c, {
            "sink": sinkOf(c)
        });
        check("out of the call: copy back", copies().length, 3);
    }

    function step3() {
        // --- The delay of one copy restarts that copy only ------------------------------
        const before = live();
        session.setDelay(c, 120);
        const after = live();
        check("a delayed copy carries it", after.filter(p => p.command.length === 7).map(p => p.command[6]), ["0.120"]);
        check("only that copy was replaced", before.filter(p => after.indexOf(p) >= 0).length, 2);
        check("the delay is 0..500", session.delays, {
            "AA:BB:CC:DD:EE:03": 120
        });
        session.setDelay(c, 900);
        check("too long is capped", session.delays["AA:BB:CC:DD:EE:03"], 500);
        session.setDelay(e, 100);
        check("a delay for a stranger is ignored", e in session.delays, false);
    }

    function step4() {
        // --- A member disconnects: the others go on ---------------------------------------
        patch(c, {
            "connected": false,
            "sink": null
        });
    }

    function step5() {
        check("the member is out", session.members, [a, b, d]);
        check("it was told", h.leaves, ["03"]);
        check("its copy and its delay left with it", [copies(), session.delays], [["02<-01pc", "04<-01pc"],
            {}
        ]);

        // --- The source leaves: another takes over --------------------------------------
        check("the source leaves on request", session.remove(a), null);
        check("the others go on", [session.members, session.source], [[b, d], b]);
        check("the sound is now taken from the first of them (it has a filter too)", copies(), ["04<-02pc"]);
        check("a stranger cannot be removed", session.remove(e).why, "not-member");
    }

    function step6() {
        // --- Fewer than two: it ends ---------------------------------------------------
        check("the last but one leaves", session.remove(d), null);
        check("it ended with the leaver", [session.active, session.members, copies(), h.ends], [false, [], [], ["ended:04"]]);
    }

    function step7() {
        // --- Stop, a disconnect of one of two, a copy that dies ---------------------------------
        h.ends = [];
        check("start again", session.start([a, b, d]), null);
        check("stop by the user", session.end("ended", ""), true);
        check("it said so", [h.ends, copies()], [["ended:"], []]);
        check("stop with nothing to stop", session.end("ended", ""), false);

        h.ends = [];
        session.start([b, d]);
        patch(d, {
            "connected": false
        });
    }

    function step8() {
        check("one of two disconnects: it ends by itself", [session.active, h.ends, copies()], [false, ["member-left:04"], []]);
        patch(d, {
            "connected": true
        });

        h.ends = [];
        session.start([a, b]);
        live()[0].exited(1);
        check("a copy that dies ends the session", [session.active, h.ends], [false, ["link-stopped:"]]);
    }

    function step9() {
        // --- The level the members share ------------------------------------------------------
        plug(a, 0.7);
        plug(b, 0.2);
        plug(c, 0.4);
        plug(d);
        session.start([a, b]);
        check("the newcomer starts at the source's level", route.devices[b].pc.audio.volume, 0.7);
        session.join(c, a);
        check("so does the next", route.devices[c].pc.audio.volume, 0.7);
        check("the shared nodes are every member's filter", session.sharedNodes.map(n => n.name), ["orbit_pc_" + key(a), "orbit_pc_" + key(b), "orbit_pc_" + key(c)]);
        check("the face shows the source's", session.sharedNode.name, "orbit_pc_" + key(a));
        session.join(d, a);
        check("a member without a filter has none to share", session.sharedNodes.length, 3);
        session.end("ended", "");

        // A source without a filter is copied after its level: nothing is shared
        plug(a);
        plug(b, 0.2);
        session.start([a, b]);
        check("a source without a filter: nothing is shared", [session.sharedNodes.length, route.devices[b].pc.audio.volume], [0, 0.2]);
        check("its copy is taken from its output", copies(), ["02<-01"]);
        session.end("ended", "");
    }
}
