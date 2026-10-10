import QtQuick
import Quickshell.Io
import "components/together"
import "components/volume/Route.js" as Route

// Test of Listen together (TogetherSession and its copies): who is in and who
// is not, which copies run for them (one per member that is copied to, a
// newcomer never cuts the others), what happens when a member is away, in a
// call or gone (D279: away keeps its place, only a Bluetooth disconnect or
// the user removes it), when the session ends, and the level the members
// share; then the wired outputs of D298 (members found by their node, the
// source filter of a wired source, the waits read from the graph). The
// processes are the stand-in of Quickshell.Io listed in ProcessLog. Run with
// tests/qml/run.sh.
Item {
    id: h

    // A fake AudioRoute: devices by address and wired outputs by node name,
    // each replaced as a whole when one changes
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

    readonly property string a: "AA:BB:CC:DD:EE:01"
    readonly property string b: "AA:BB:CC:DD:EE:02"
    readonly property string c: "AA:BB:CC:DD:EE:03"
    readonly property string d: "AA:BB:CC:DD:EE:04"
    readonly property string e: "AA:BB:CC:DD:EE:05"
    // Two made-up wired outputs (D298)
    readonly property string w1: "alsa_output.test_one"
    readonly property string w2: "alsa_output.test_two"

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

    // The processes of the session: the copies and the source filter of a wired
    // source, not the graph reader
    function live() {
        return ProcessLog.live.filter(p => p.command[0] !== "pw-dump");
    }
    // A node as the lines below name it: a Bluetooth output or filter by the
    // last two digits of its address (and "pc" for the filter), a wired output
    // by its name after "alsa_output.", the source filter of one as "f-" and that
    function labelOf(node) {
        if (/^orbit_wired_w_/.test(node))
            return "f-" + node.slice(14, -17);
        if (/^alsa_output\./.test(node))
            return node.slice(12);
        return /([0-9A-F]{2})(\.1)?$/.exec(node)[1] + (/^orbit_pc_/.test(node) ? "pc" : "");
    }
    // The copies that run, as "member <- where it is copied from", and the
    // source filter as "filter(wired output)"
    function copies() {
        const out = [];
        for (const p of live()) {
            if (/media\.class=Audio\/Sink/.test(p.command[4])) {
                out.push("filter(" + /node\.name = "alsa_output\.([^"]*)"/.exec(p.command[4])[1] + ")");
                continue;
            }
            const m = /node\.name=orbit_together_(\S+?)_in\s/.exec(p.command[4])[1];
            const member = /^w_/.test(m) ? m.slice(2, -17) : m.slice(-2);
            out.push(member + "<-" + labelOf(/target\.object=(\S+)\s/.exec(p.command[4])[1]));
        }
        return out.sort();
    }
    // A wired output node, as PipeWire lists it, and the source filter in front of it
    function wire(name, description) {
        const next = Object.assign({}, route.wired);
        next[name] = {
            "name": name,
            "description": description,
            "nickname": "",
            "audio": {
                "volume": 1,
                "muted": false
            }
        };
        route.wired = next;
    }
    function unwire(name) {
        const next = Object.assign({}, route.wired);
        delete next[name];
        route.wired = next;
    }
    function filterUp(name, up) {
        const next = Object.assign({}, route.filters);
        if (up)
            next[name] = {
                "name": Route.wiredFilterName(name)
            };
        else
            delete next[name];
        route.filters = next;
    }
    // What `pw-dump` says: each output's name with the time it reports (ns, 0 for none)
    function dumpOf(latencies) {
        return JSON.stringify(Object.keys(latencies).map(name => ({
                    "info": {
                        "props": {
                            "media.class": "Audio/Sink",
                            "node.name": name
                        },
                        "params": {
                            "Latency": [
                                {
                                    "direction": "Input",
                                    "maxNs": latencies[name]
                                }
                            ]
                        }
                    }
                })));
    }
    // The graph reader asked for its answer: gives it, and says it is over
    function answerGraph(latencies) {
        const reader = ProcessLog.live.find(p => p.command[0] === "pw-dump");
        if (!reader || !reader.running)
            return false;
        reader.stdout.text = dumpOf(latencies);
        reader.running = false;
        reader.exited(0);
        return true;
    }
    function readerRunning() {
        return ProcessLog.live.some(p => p.command[0] === "pw-dump" && p.running);
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
    property var unknowns: []
    Connections {
        target: session
        function onEnded(why, address) {
            h.ends = h.ends.concat([why + ":" + address.slice(-2)]);
        }
        function onLatencyUnknown(address) {
            h.unknowns = h.unknowns.concat([address.slice(-2)]);
        }
        function onMemberLeft(address) {
            h.leaves = h.leaves.concat([address.slice(-2)]);
        }
    }

    // The steps run one after another, a turn of the event loop apart: a member
    // that disconnects leaves once the update that told so is over
    property var steps: []
    property int next: 0
    // A step that must let a timer of the code run (the graph reader waits
    // 400 ms) holds the next one until this time
    property double holdUntil: 0
    function wait(ms) {
        holdUntil = Date.now() + ms;
    }
    // Long enough for the member that left to be taken out (Qt.callLater runs
    // when it likes relative to a 1 ms timer, more so on a busy machine)
    readonly property int leaveMs: 30
    Timer {
        id: stepper
        // 1 ms: a 0 ms timer never fires under the offscreen test platform
        interval: 1
        repeat: true
        running: false
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
        steps = [step1, step2, step3, step4, step5, step6, step7, step8, step9, step10, step11, step12, step13, step14, step15, step16, step17, step18, step19];
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
        check("an output with sound may take part, one Orbit does not see may not", [session.memberCheck(a), session.memberCheck("AA:BB:CC:DD:EE:09").why], [null, "not-connected"]);
        check("what is no output at all is not there either", [session.memberCheck("x; reboot").why, session.memberCheck(5).why, session.memberCheck(null).why], ["not-connected", "not-connected", "not-connected"]);

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
        check("the chooser is told why it cannot be ticked", session.memberCheck(b).why, "no-audio");
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
        check("and the chooser says it is in a call", session.memberCheck(c).why, "in-call");
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
        check("the delay is 0..1000", session.delays, {
            "AA:BB:CC:DD:EE:03": 120
        });
        session.setDelay(c, 9000);
        check("too long is capped", session.delays["AA:BB:CC:DD:EE:03"], 1000);
        session.setDelay(e, 100);
        check("a delay for a stranger is ignored", e in session.delays, false);
    }

    function step4() {
        // --- A member disconnects: the others go on ---------------------------------------
        patch(c, {
            "connected": false,
            "sink": null
        });
        h.wait(h.leaveMs);
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
        h.wait(h.leaveMs);
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
        // Its filter comes up later (it was away, or slow): shared level and mute, not its own saved one
        patch(d, {
            "pc": {
                "name": "orbit_pc_" + key(d),
                "audio": {
                    "volume": 1,
                    "muted": false
                }
            }
        });
        route.devices[a].pc.audio.muted = true;
        session.realign(d);
        check("a filter that came up late follows the shared level and mute", [route.devices[d].pc.audio.volume, route.devices[d].pc.audio.muted], [0.7, true]);
        session.realign(e);
        check("a device that is not a member is left alone", route.devices[e].pc, null);
        session.end("ended", "");

        // A source without a filter is copied after its level: nothing is shared
        plug(a);
        plug(b, 0.2);
        session.start([a, b]);
        check("a source without a filter: nothing is shared", [session.sharedNodes.length, route.devices[b].pc.audio.volume], [0, 0.2]);
        check("its copy is taken from its output", copies(), ["02<-01"]);
        // The source's own filter comes up: the others follow it
        patch(a, {
            "pc": {
                "name": "orbit_pc_" + key(a),
                "audio": {
                    "volume": 0.9,
                    "muted": false
                }
            }
        });
        session.realign(a);
        check("the source's filter came up: the others follow", route.devices[b].pc.audio.volume, 0.9);
        session.end("ended", "");
    }

    // The sink of a Bluetooth output with the codec it plays
    function sinkWith(address, codec) {
        const s = sinkOf(address);
        s.properties["api.bluez5.codec"] = codec;
        return s;
    }
    // The wired outputs' process: the source filter's, or null
    function filterProcess() {
        return live().find(p => /media\.class=Audio\/Sink/.test(p.command[4])) || null;
    }
    // The wait of each copy, sorted: a copy that restarts changes places
    function copyDelays() {
        return live().filter(p => p.command.length === 7).map(p => p.command[6]).sort();
    }
    function copyProcess() {
        return live().find(p => !/media\.class=Audio\/Sink/.test(p.command[4])) || null;
    }

    function step10() {
        // --- A wired output next to a Bluetooth one (D298) --------------------------------
        plug(a, 0.7);
        plug(b);
        wire(w1, "Studio\u0007 Interface");
        wire(w2, "Headset");
        check("a wired output is a member by its node", session.check([w1, b]), null);
        check("one that is not there is not connected", session.check([w1, "alsa_output.test_gone"]).why, "not-connected");
        check("a name that is not an output's is refused", [session.check([w1, "alsa_output.x y"]).why, session.check([w1, "alsa_output.a..b"]).why, session.check([w1, "nonsense"]).why], ["bad-address", "bad-address", "bad-address"]);
        check("a wired output has the name of its node, cleaned", [session.nameOf(w1), session.nameOf("alsa_output.test_gone")], ["Studio Interface", ""]);
        check("a wired output takes part with a drop too", session.dropCheck(w1, b), null);

        check("start with a wired source and a Bluetooth output", session.start([w1, b]), null);
        check("the first with an output is the source", [session.members, session.source], [[w1, b], w1]);
        check("with no wait the filter still runs, the copy reads the sink until it is up", copies(), ["02<-test_one", "filter(test_one)"]);
        check("the filter made up no wait: its command has no delay argument", filterProcess().command.length, 6);
        filterUp(w1, true);
        check("the filter is up: the copy reads its monitor, so the source's tick stays out of it", copies(), ["02<-f-test_one", "filter(test_one)"]);
        check("the face shows the wired source's own level", [session.sharedNode === route.wired[w1], session.memberNode(w2) === route.wired[w2], session.sharedNodes.length], [true, true, 0]);

        check("a wired output joins by a drop onto a member", [session.join(w2, b), session.members], [null, [w1, b, w2]]);
        check("its copy reads the same source", copies(), ["02<-f-test_one", "filter(test_one)", "test_two<-f-test_one"]);
        check("a wired output can be removed", [session.remove(w2), session.members], [null, [w1, b]]);
        // Back to the state the next steps start from: the filter has not come up yet
        filterUp(w1, false);

        h.wait(500);
    }

    function step11() {
        check("the graph is read once, a moment after the session forms", readerRunning(), true);
        check("it answers: 218 ms for the headset, nothing for the wired output", answerGraph({
            "alsa_output.test_one": 0,
            "bluez_output.AA_BB_CC_DD_EE_02.1": 218000000
        }), true);
        check("the wired source waits in its own filter, the copy goes on", copies(), ["02<-test_one", "filter(test_one)"]);
        check("it waits as long as the Bluetooth output adds", filterProcess().command[6], "0.218");

        const filter = filterProcess();
        const copy = copyProcess();
        filterUp(w1, true);
        check("the filter is up: the copy reads its monitor, the filter stays", [copies(), live().indexOf(filter) >= 0], [["02<-f-test_one", "filter(test_one)"], true]);
        check("the copy was restarted to read it", live().indexOf(copy), -1);

        const reading = copyProcess();
        session.fineDelayMs = 30;
        check("a nudge moves the wait: the filter is replaced", [filterProcess() !== filter, filterProcess().command[6]], [true, "0.248"]);
        check("the copy was not restarted", copyProcess() === reading, true);

        const nudged = filterProcess();
        session.setDelay(b, 50);
        check("a delay of the headset's own is its copy's, the filter is left alone", [copyProcess().command[6], filterProcess() === nudged], ["0.050", true]);
        session.setDelay(b, 0);
        session.fineDelayMs = 0;
        check("both back to nothing", [filterProcess().command[6], copyProcess().command.length], ["0.218", 6]);

        // The headset changes its codec: the graph is read again
        patch(b, {
            "sink": sinkWith(b, "ldac")
        });
        h.wait(500);
    }

    function step12() {
        check("a codec change makes the graph be read again", readerRunning(), true);
        check("the new figure moves the wait", [answerGraph({
                "alsa_output.test_one": 0,
                "bluez_output.AA_BB_CC_DD_EE_02.1": 150000000
            }), filterProcess().command[6]], [true, "0.150"]);

        // The wired source is unplugged: it leaves, and with fewer than two the session ends
        h.ends = [];
        unwire(w1);
        filterUp(w1, false);
        h.wait(h.leaveMs);
    }

    function step13() {
        check("an unplugged wired output ends a session of two", [session.active, h.ends, copies()], [false, ["member-left:ne"], []]);
        check("nothing reads the graph outside a session", ProcessLog.live.some(p => p.command[0] === "pw-dump"), false);

        // A Bluetooth source, a wired output to copy to
        h.ends = [];
        wire(w1, "Studio Interface");
        plug(a, 0.7);
        plug(b);
        check("start with a Bluetooth source and a wired output", session.start([a, w2]), null);
        check("the wired member is copied to, from the source's filter", [session.source, copies()], [a, ["test_two<-01pc"]]);
        check("a wired output that is there may take part, one that is not may not", [session.memberCheck(w2), session.memberCheck("alsa_output.test_never").why], [null, "not-connected"]);
        check("only the source's level is shared", session.sharedNodes.map(n => n.name), ["orbit_pc_" + key(a)]);
        h.wait(500);
    }

    function step14() {
        check("the graph said 200 ms for the Bluetooth output, nothing for the wired one", answerGraph({
            "bluez_output.AA_BB_CC_DD_EE_01.1": 200000000,
            "alsa_output.test_two": 0
        }), true);
        check("the wired copy waits for it, there is no filter", [copyProcess().command[6], filterProcess()], ["0.200", null]);
        session.fineDelayMs = 20;
        check("the nudge moves the wired copy", copyProcess().command[6], "0.220");
        session.fineDelayMs = -9999;
        check("a nudge is held within 100 ms either way", copyProcess().command[6], "0.100");
        session.fineDelayMs = 0;
        h.unknowns = [];
        check("a Bluetooth copy joins with no figure yet and keeps its timing", [session.join(b, a), copies(), live().filter(p => p.command.length === 7).length], [null, ["02<-01pc", "test_two<-01pc"], 1]);
        h.wait(500);
    }

    function step15() {
        check("the new member is read", readerRunning(), true);
        check("the graph knows the source and the wired output, not the new member", answerGraph({
            "bluez_output.AA_BB_CC_DD_EE_01.1": 200000000,
            "alsa_output.test_two": 0
        }), true);
        check("the output without a figure is told, once, and keeps its timing", [h.unknowns, copyDelays()], [["02"], ["0.200"]]);
        // Its codec shows: the graph is read again, once
        patch(b, {
            "sink": {
                "name": sinkOf(b).name,
                "properties": {
                    "api.bluez5.profile": "a2dp-sink",
                    "api.bluez5.codec": "aac"
                }
            }
        });
        h.wait(500);
    }

    function step16() {
        check("the codec change makes one more read", readerRunning(), true);
        h.unknowns = [];
        check("it gives the Bluetooth output 60 ms", answerGraph({
            "bluez_output.AA_BB_CC_DD_EE_01.1": 200000000,
            "bluez_output.AA_BB_CC_DD_EE_02.1": 60000000,
            "alsa_output.test_two": 0
        }), true);
        check("the quicker Bluetooth copy waits for the difference, the wired one for the source", [copyDelays(), h.unknowns], [["0.140", "0.200"], []]);
        session.setDelay(b, 30);
        check("the user's own delay is added: it stays an override", copyDelays(), ["0.170", "0.200"]);
        session.fineDelayMs = 20;
        check("the nudge moves the wired copy only", copyDelays(), ["0.170", "0.220"]);
        session.fineDelayMs = 0;
        h.wait(300);
    }

    function step17() {
        check("nothing reads the graph once the figures are in", readerRunning(), false);
        session.end("ended", "");
        check("the session ended: nothing is left running", [live().length, ProcessLog.live.length], [0, 0]);

        // A wired source has no filter of the PC level: the level it shows reaches the Bluetooth filters (D368)
        plug(a, 0.7);
        plug(b, 0.2);
        wire(w1, "Studio Interface");
        session.start([w1, b]);
        check("a wired source shares its level with the Bluetooth filters", session.sharedNodes.map(n => n.name), [w1, "orbit_pc_" + key(b)]);
        check("the face shows the output's own level", session.sharedNode === route.wired[w1], true);
        check("a newcomer is not set to the sound card's level", route.devices[b].pc.audio.volume, 0.2);
        Route.writeLevel(session.sharedNodes, session.sharedNode, 0.4);
        check("moving it moves the filter too", [route.wired[w1].audio.volume, route.devices[b].pc.audio.volume], [0.4, 0.4]);
        h.wait(500);
    }

    function step18() {
        check("the first read gives the Bluetooth output its figure", [answerGraph({
                [w1]: 0,
                "bluez_output.AA_BB_CC_DD_EE_02.1": 150000000
            }), session.latencies[b]], [true, 150]);
        patch(b, {
            "sink": sinkWith(b, "ldac")
        });
        h.wait(500);
    }

    function step19() {
        const reader = ProcessLog.live.find(p => p.command[0] === "pw-dump");
        reader.running = false;
        reader.exited(1);
        check("a failed read keeps no figure of the read before", session.latencies, {});
        session.end("ended", "");
    }
}
