import QtQuick
import QtTest
import Quickshell.Services.Pipewire
import qs.Common
import qs.Services
import "components/centre"
import "components/scene"
import "components/scene/Physics.js" as Physics
import "components/together"
import "components/together/Habits.js" as Habits
import "mock"
import "mock/Devices.js" as Devices
import "mock/State.js" as State

// Test of the ghost group (D298): while the sound goes to a wired output and a
// Bluetooth device is connected, or the other way round, a dotted planet on the
// host's ring proposes to listen together. The first part runs OrbitGhost on its
// own over a real TogetherSession: what it proposes (and what it leaves out,
// each with its counter-proof), that a refusal is remembered by the set until
// the shell ends, never during a session, never when the engine would refuse,
// what a click does and says, the fade, that a learned group (D299) is proposed
// whole while the pair is what is proposed without one, that a hidden output is
// left out, and that a closed orbit reads and runs nothing. The second part runs the whole scene with real mouse events: the
// ghost takes a slot on the ring like the group would, the loop still settles
// with Reduce motion, a click or a cross answers, and the group takes over. The
// scene runs on its real timers, so each step waits a moment. Run with
// tests/qml/run.sh.
Item {
    id: h
    width: 520
    height: 440

    readonly property string headset: "02:00:00:00:10:06"
    readonly property string one: "02:00:00:00:20:01"
    readonly property string two: "02:00:00:00:20:02"
    // Made-up wired outputs
    readonly property string dongle: "alsa_output.usb-Acme_Dongle-00.analog-stereo"
    readonly property string studio: "alsa_output.usb-Acme_Studio-00.analog-stereo"

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // --- PipeWire's side ---------------------------------------------------------------------
    component Sink: QtObject {
        property string name: ""
        readonly property bool isSink: true
        readonly property bool isStream: false
    }
    Sink {
        id: dongleNode
        name: h.dongle
    }
    Sink {
        id: studioNode
        name: h.studio
    }
    // Orbit's own virtual node: not a wired output, and not a device
    Sink {
        id: virtualNode
        name: "orbit_pc_filter"
    }
    function pipewire(defaultSink, extra) {
        Pipewire.defaultAudioSink = defaultSink;
        Pipewire.extraSinks = extra;
    }

    // --- Part 1: the ghost on its own, over a real session ----------------------------------
    // A made-up route: the devices as TogetherSession reads them, the ones that play
    // sound and the one in use (AudioRoute's), and the wired outputs PipeWire lists
    QtObject {
        id: soloRoute
        property var devices: ({})
        property var wired: ({})
        property var audio: []
        property var current: null
        function audioDevices() {
            return audio;
        }
        function known(address) {
            return devices[address] || null;
        }
        function wiredSink(name) {
            return wired[name] || null;
        }
        function wiredFilter(name) {
            return null;
        }
        function deviceNode(device) {
            return null;
        }
        function pcNode(device) {
            return device.pc || device.sink;
        }
    }
    // The session is the daemon's, and it is what remembers the refusals: making it
    // again is what the end of the shell does to them
    Loader {
        id: daemon
        sourceComponent: TogetherSession {
            route: soloRoute
        }
    }
    // The part of the scene the ghost reads
    QtObject {
        id: solo
        property bool active: true
        property bool awake: true
        property bool motion: true
        property var prefs: ({
                "togetherCentre": true
            })
        property var audioRoute: soloRoute
        readonly property real coreSize: 75
        property var note: null
        property int wakes: 0
        function wake() {
            wakes++;
        }
        function explain(n) {
            note = n;
        }
        readonly property var together: QtObject {
            function nameOf(address) {
                return daemon.item ? daemon.item.nameOf(address) : "";
            }
        }
        readonly property var sounds: QtObject {
            property var played: []
            function play(name) {
                played = played.concat([name]);
            }
        }
    }
    QtObject {
        id: soloCentre
        property bool grouped: false
        property real profile: 0
    }
    OrbitGhost {
        id: ghost
        scene: solo
        centre: soloCentre
        session: daemon.item
    }
    // A session that accepts the proposal but refuses the click (a device went away
    // between the two)
    QtObject {
        id: refusing
        property bool active: false
        property var started: []
        function check(list) {
            return null;
        }
        function start(list) {
            started = started.concat([list]);
            return {
                "why": "not-connected",
                "address": list[1]
            };
        }
        function isDeclined(key) {
            return false;
        }
        function decline(key) {
        }
    }
    OrbitGhost {
        id: refused
        scene: solo
        centre: soloCentre
        session: refusing
    }

    function plug(address, name) {
        const key = address.replace(/:/g, "_");
        const device = {
            "address": address,
            "name": name,
            "connected": true,
            "sink": {
                "name": "bluez_output." + key + ".1",
                "properties": {
                    "api.bluez5.profile": "a2dp-sink"
                }
            },
            "pc": null
        };
        soloRoute.devices = Object.assign({}, soloRoute.devices, {
            [address]: device
        });
        soloRoute.audio = soloRoute.audio.filter(d => d.address !== address).concat([device]);
    }
    function unplug(address) {
        const next = Object.assign({}, soloRoute.devices);
        delete next[address];
        soloRoute.devices = next;
        soloRoute.audio = soloRoute.audio.filter(d => d.address !== address);
        if (soloRoute.current && soloRoute.current.address === address)
            soloRoute.current = null;
    }
    // A device that is in a call: the engine refuses it (the headset profile plays mono)
    function inCall(address, on) {
        const d = soloRoute.devices[address];
        d.sink.properties["api.bluez5.profile"] = on ? "headset-head-unit" : "a2dp-sink";
        soloRoute.devices = Object.assign({}, soloRoute.devices);
        soloRoute.audio = soloRoute.audio.slice();
    }
    function wire(name, description, on) {
        const next = Object.assign({}, soloRoute.wired);
        if (on)
            next[name] = {
                "name": name,
                "description": description,
                "nickname": "",
                "audio": {
                    "volume": 1,
                    "muted": false
                }
            };
        else
            delete next[name];
        soloRoute.wired = next;
    }

    // The reader of the plugged outputs inside a ghost, and the command it runs
    function watchOf(g) {
        for (let i = 0; i < g.data.length; i++)
            if (g.data[i].objectName === "wiredWatch")
                return g.data[i];
        return null;
    }
    function runnerOf(g) {
        const w = watchOf(g);
        for (let i = 0; i < w.data.length; i++)
            if (w.data[i].command !== undefined)
                return w.data[i];
        return null;
    }
    function finish(g, code, text) {
        const run = runnerOf(g);
        run.stdout.text = text;
        run.running = false;
        run.exited(code);
    }
    // What `pactl list sinks` says for these plugged outputs, cut down to what is read
    function listing(names) {
        return JSON.stringify(names.map(n => ({
                    "name": n,
                    "description": n === h.dongle ? "Dongle Stereo" : "Studio Stereo",
                    "active_port": "analog-output",
                    "ports": [
                        {
                            "name": "analog-output",
                            "availability": "availability unknown"
                        }
                    ],
                    "properties": {
                        "device.bus": "usb"
                    }
                })));
    }
    // Steps of the scene's loop, as OrbitPhysics gives them
    function run(g, seconds) {
        for (let i = 0; i < Math.round(seconds * 10); i++)
            g.advance(0.1);
    }

    function alone() {
        const session = () => daemon.item;
        check("nothing plays: no proposal", [ghost.offered, ghost.shown, ghost.key], [false, false, ""]);

        // The sound goes to a wired output
        wire(h.dongle, "Dongle Stereo", true);
        h.pipewire(dongleNode, [dongleNode]);
        check("a wired output and no Bluetooth device: nothing to put it with", ghost.offered, false);
        plug(h.headset, "Pulse BT");
        check("a Bluetooth device is connected: the ghost is offered", ghost.offered, true);
        check("the output in use comes first", ghost.proposal.members, [h.dongle, h.headset]);
        check("the key is the set: the same whatever the order", ghost.key, [h.headset, h.dongle].join(","));
        check("a wired output is read from PipeWire's names, not from a command", runnerOf(ghost).running, false);

        // What the engine would refuse is not proposed
        inCall(h.headset, true);
        check("counter-proof: a headset in call mode is left out, so nothing is promised", ghost.offered, false);
        inCall(h.headset, false);
        check("back on music it is offered again", ghost.offered, true);
        unplug(h.headset);
        check("counter-proof: the Bluetooth device goes away, the ghost goes", ghost.offered, false);
        plug(h.headset, "Pulse BT");
        h.pipewire(virtualNode, [virtualNode]);
        check("counter-proof: the output in use is neither wired nor Bluetooth: no ghost", [ghost.offered, ghost.key], [false, ""]);
        h.pipewire(dongleNode, [dongleNode]);
        check("and with the wired output back it returns", ghost.offered, true);

        // The setting and the group at the centre
        solo.prefs = {
            "togetherCentre": false
        };
        check("the group at the centre is off: no ghost, it would have no place", ghost.offered, false);
        solo.prefs = {
            "togetherCentre": true
        };
        soloCentre.grouped = true;
        check("a group has the centre: no ghost", ghost.offered, false);
        soloCentre.grouped = false;
        check("counter-proof: both back, it is offered", ghost.offered, true);

        // The fade is stepped by the scene's loop, a few tenths of a second
        check("it has not arrived yet: nothing is drawn", [ghost.presence, ghost.shown, ghost.fading], [0, true, true]);
        ghost.advance(0.1);
        check("it comes in ...", [ghost.presence, ghost.fading], [0.4, true]);
        run(ghost, 0.2);
        check("... in a quarter of a second", [ghost.presence, ghost.fading], [1, false]);
        solo.motion = false;
        ghost.decline();
        ghost.advance(0.001);
        check("Reduce motion: it goes at once, no fade", [ghost.presence, ghost.shown], [0, false]);
        solo.motion = true;
        plug(h.one, "Pulse Two");
        check("counter-proof: a third output changes nothing without a memory: still the pair that was turned down", [ghost.offered, ghost.proposal.members], [false, [h.dongle, h.headset]]);
        const learned = Habits.record({}, [h.dongle, h.headset, h.one], Date.now());
        solo.prefs = {
            "togetherCentre": true,
            "learnHabits": true,
            "togetherHabits": learned
        };
        check("a learned group is a different set: refused is not forgotten for it, and it is proposed whole", [ghost.offered, ghost.proposal.members], [true, [h.dongle, h.headset, h.one]]);
        solo.prefs = {
            "togetherCentre": true,
            "learnHabits": false,
            "togetherHabits": learned
        };
        check("counter-proof: learning is off, the memory is not used: the pair again", [ghost.offered, ghost.proposal.members], [false, [h.dongle, h.headset]]);
        solo.prefs = {
            "togetherCentre": true,
            "learnHabits": true,
            "togetherHabits": learned,
            "hiddenDevices": {
                [h.one]: "Pulse Two"
            }
        };
        check("a hidden output is left out of the learned group: the pair", [ghost.offered, ghost.proposal.members], [false, [h.dongle, h.headset]]);
        solo.prefs = {
            "togetherCentre": true
        };
        unplug(h.one);

        // A refusal
        check("turned down: not offered, though the set still stands", [ghost.offered, ghost.key !== ""], [false, true]);
        check("the session remembers it by the set", Object.keys(session().declined), [ghost.key]);
        check("while it lasts the ghost is still on its way out", ghost.shown, false);
        check("counter-proof: a nonsense key is not remembered", [session().isDeclined(""), session().isDeclined("nonsense")], [false, false]);
        daemon.active = false;
        check("the shell ends: no session, no ghost", ghost.offered, false);
        daemon.active = true;
        check("a new shell starts with no refusal: the ghost is back", [ghost.offered, Object.keys(session().declined)], [true, []]);

        // Never during a session
        ghost.advance(0.1);
        check("a click: the group is started with exactly what was shown", [ghost.accept(), session().members, solo.sounds.played], [undefined, [h.dongle, h.headset], ["connect"]]);
        check("a session is on: the ghost goes, whatever it would put together", [ghost.offered, session().active], [false, true]);
        run(ghost, 0.5);
        check("and it is gone, not fading", [ghost.shown, ghost.presence], [false, 0]);
        check("a group the user ended is not proposed again at once", [session().end("ended", ""), session().isDeclined(ghost.key), ghost.offered], [true, true, false]);

        // ... but one that ended by itself may be
        daemon.active = false;
        daemon.active = true;
        check("(a new shell)", ghost.offered, true);
        ghost.accept();
        check("a session again", session().active, true);
        session().end("member-left", h.headset);
        check("counter-proof: a group that ended because a device left is not turned down", [session().isDeclined(ghost.key), ghost.offered], [false, true]);

        // Where it sits and what it looks like
        ghost.place({
            "x": 120,
            "y": 80,
            "depth": -1
        });
        check("on the far side of the ring it is small, faint and behind the host's core", [ghost.px, ghost.py, ghost.depth, ghost.diameter, ghost.haze, ghost.stack], [120, 80, -1, 26.25, 0.9, 10.8]);
        ghost.place({
            "x": 120,
            "y": 300,
            "depth": 1
        });
        check("on the near side it is the group's size, in front, sorted by height", [ghost.diameter, ghost.haze, ghost.stack], [52.5, 1, 400]);
        check("it is placed once the step laid the ring out ...", ghost.placed, true);
        ghost.decline();
        run(ghost, 0.5);
        check("... and not any more once it is gone, so it never shows at the corner", [ghost.shown, ghost.placed], [false, false]);

        // A click the engine refuses is told, never left silent (value 10)
        solo.sounds.played = [];
        refused.advance(1);
        check("a session that will refuse still gets its proposal shown", refused.offered, true);
        refused.accept();
        check("the click was passed on, with the list shown", refusing.started, [[h.dongle, h.headset]]);
        check("it is said why, with the way to the guide", solo.note ? [solo.note.title, solo.note.anchor] : null, ["Pulse BT is not connected", "listen-together"]);
        check("no sound of a connection", solo.sounds.played, []);
        solo.note = null;
    }

    // The sound goes to a Bluetooth device, a wired output is plugged in: the plugged
    // outputs are read, once, and again only when something that could change them did
    function other() {
        // A new shell: the group turned down above is proposed again
        daemon.active = false;
        daemon.active = true;
        wire(h.dongle, "Dongle Stereo", true);
        wire(h.studio, "Studio Stereo", true);
        h.pipewire(null, []);
        soloRoute.current = soloRoute.devices[h.headset];
        const reader = runnerOf(ghost);
        check("the sound goes to Bluetooth: the plugged outputs are asked for, once", [reader.running, reader.command], [true, ["pactl", "--format=json", "list", "sinks"]]);
        check("(nothing is proposed until they are known)", ghost.offered, false);
        finish(ghost, 0, listing([h.dongle]));
        check("a wired output is plugged in: the ghost is offered, the output in use first", [ghost.offered, ghost.proposal.members], [true, [h.headset, h.dongle]]);
        check("it is the same set as the other way round", ghost.key, [h.headset, h.dongle].join(","));
        check("nothing runs between two changes", reader.running, false);
        h.pipewire(null, [studioNode]);
        check("a wired output appears among PipeWire's nodes: the list is read again", reader.running, true);
        finish(ghost, 0, listing([h.dongle, h.studio]));
        check("a pair only: the output in use and the first of them", ghost.proposal.members, [h.headset, h.dongle]);
        solo.prefs = {
            "togetherCentre": true,
            "learnHabits": true,
            "togetherHabits": Habits.record({}, [h.headset, h.dongle, h.studio], Date.now())
        };
        check("a learned group is proposed whole, the output in use first", ghost.proposal.members, [h.headset, h.dongle, h.studio]);
        solo.prefs = {
            "togetherCentre": true
        };
        finish(ghost, 0, "[]");
        check("counter-proof: everything is unplugged: no ghost", ghost.offered, false);

        // A closed orbit reads nothing and runs nothing
        reader.running = false;
        finish(ghost, 0, listing([h.dongle]));
        run(ghost, 0.5);
        check("plugged again: it is offered, and it is there", [ghost.offered, ghost.presence], [true, 1]);
        solo.active = false;
        solo.awake = false;
        check("the orbit is closed: the reader is off and the list dropped", [watchOf(ghost).active, watchOf(ghost).outputs, ghost.offered], [false, [], false]);
        check("and no ghost is left behind", [ghost.shown, ghost.presence], [false, 0]);
        h.pipewire(null, [studioNode, dongleNode]);
        check("counter-proof: a change while it is closed runs nothing", reader.running, false);
        solo.active = true;
        solo.awake = true;
        check("opened again: the list is read again", reader.running, true);
        solo.sounds.played = [];

        h.pipewire(null, []);
        soloRoute.current = null;
        solo.active = true;
        solo.awake = true;
        wire(h.dongle, "", false);
        wire(h.studio, "", false);
        unplug(h.headset);
    }

    // --- Part 2: the whole scene, with real mouse events ------------------------------------------
    FakeRoute {
        id: route
    }
    OrbitScene {
        id: scene
        anchors.fill: parent
        active: true
        autoScan: false
        previewDevices: Devices.list(false, 2)
        audioRoute: route
    }
    // Only here for its mouse events: left to run (`when` true) it would find no test
    // function, finish and quit the whole test before the steps
    TestCase {
        id: mouse
        name: "ghostGroup"
        when: false
    }

    // How many texts are drawn in the subtree (a name would be one)
    function texts(item) {
        let n = "text" in item && item.visible ? 1 : 0;
        for (const child of item.children)
            n += texts(child);
        return n;
    }

    // The connected ring's neighbours: how many, and the gaps between them (rad), seen
    // from the middle of the ring
    function ringGaps() {
        const ring = scene.world.bodyList().filter(b => b.inSlot && !b.leaving);
        const angles = ring.map(b => Math.atan2((b.py - scene.ringCy) / scene.ringRy, (b.px - scene.cx) / (scene.rx * scene.innerNorm))).sort((a, b) => a - b);
        const gaps = angles.map((a, i) => (i + 1 < angles.length ? angles[i + 1] : angles[0] + 2 * Math.PI) - a);
        return {
            "n": ring.length,
            "biggest": Math.max(...gaps),
            "smallest": Math.min(...gaps)
        };
    }
    // Evenly spaced: n slots, each 2π/n from the next
    function even(gaps, n) {
        const slot = 2 * Math.PI / n;
        return Math.abs(gaps.biggest - slot) < 0.1 && Math.abs(gaps.smallest - slot) < 0.1;
    }
    // One slot kept for the ghost: n + 1 slots, and the ghost's own between two of them
    function reserved(gaps, n) {
        const slot = 2 * Math.PI / (n + 1);
        return Math.abs(gaps.smallest - slot) < 0.1 && Math.abs(gaps.biggest - 2 * slot) < 0.1;
    }
    function view() {
        return scene.world.ghostView.item;
    }
    // The scene's own settings, as the shell saves them: a memory that has seen this group used
    function learn(members) {
        SettingsData.pluginSettings = Object.assign({}, SettingsData.pluginSettings, {
            "togetherHabits": Habits.record({}, members, Date.now())
        });
        PluginService.pluginDataChanged("orbitBluetooth");
    }
    function clickGhost(button) {
        mouse.mouseClick(scene, scene.ghost.px, scene.ghost.py, button);
    }
    // The cross is a zone of its own: the middle of it, wherever the layout puts it
    function clickCross() {
        const z = view().cross, p = z.mapToItem(scene, z.width / 2, z.height / 2);
        mouse.mouseClick(scene, p.x, p.y, Qt.LeftButton);
    }
    property var before: ({})
    property real orbit: 0
    property string key: ""
    // Whether the loop stopped at some point (the devices' slow poll wakes it for a
    // single step now and then, so one read could land on that step)
    property bool settledSeen: false
    Timer {
        id: settleProbe
        interval: 16
        repeat: true
        onTriggered: {
            if (scene.settled)
                h.settledSeen = true;
        }
    }

    // The steps. Each one runs, then the next starts once `until` holds (the scene's own
    // loop decides when a move is over: offscreen it runs slowly, so no fixed wait is
    // right) or, with a plain `wait`, after that many ms. A step that never gets there is
    // left after 10 s, and its checks then fail: nothing waits for ever.
    readonly property var steps: [
        {
            // Reduce motion: the ring stands still, so a slot is where it stays
            "wait": 1500,
            "run": () => {
                SettingsData.reduceMotion = true;
                h.pipewire(null, []);
            }
        },
        {
            // The sound goes to a wired output and a Bluetooth device is connected: the ring
            // makes room, then the loop stops
            "until": () => h.settledSeen,
            "run": () => {
                h.before = h.ringGaps();
                check("no proposal: no ghost, the connected ring is evenly spaced", [scene.ghost.shown, h.before.n, h.even(h.before, h.before.n)], [false, 5, true]);
                check("and nothing is loaded for it", scene.world.ghostView.item, null);
                h.pipewire(dongleNode, [dongleNode]);
                route.audio = [route.headset];
                h.settledSeen = false;
                settleProbe.start();
            }
        },
        {
            "wait": 100,
            "run": () => {
                const g = scene.ghost, gaps = h.ringGaps();
                check("a wired output plays and a Bluetooth device is connected: the ghost is offered", [g.offered, g.shown, g.proposal.members], [true, true, [h.dongle, h.headset]]);
                check("it is drawn and was put on its slot", [h.view() !== null, h.view().visible, g.placed], [true, true, true]);
                check("a slot is kept for it on the ring, as for the group (counter-proof: before, the ring was even)", h.reserved(gaps, h.before.n), true);
                const slot = Physics.ringSlot(scene, 0, h.before.n + 1, scene.orbitTime * 0.11 - Math.PI / 2);
                check("it sits on the slot the real group would take", [Math.round(g.px), Math.round(g.py)], [Math.round(slot.x), Math.round(slot.y)]);
                check("it is as big as the group would be there", Math.round(g.diameter * 100), Math.round(scene.coreSize * 0.7 * (0.75 + 0.25 * slot.depth) * 100));
                check("Reduce motion: it was there at once, no fade", g.presence, 1);
                settleProbe.stop();
                check("the scene's loop settled with the ghost on the ring", h.settledSeen, true);
                const z = h.view().pointer, mid = z.width / 2;
                check("its click zone is its disc: the centre answers, the corner of its square does not", [z.contains(Qt.point(mid, mid)), z.contains(Qt.point(3, 3))], [true, false]);
                const c = h.view().cross;
                check("the cross is clear of the planet's centre (far away the planet is hardly bigger than the cross)", c.contains(c.mapFromItem(scene, g.px, g.py)), false);
                check("a card or the hidden list open: it does not answer", [h.view().live, (scene.hiddenOpen = true, h.view().live), (scene.hiddenOpen = false, h.view().live)], [true, false, true]);
                // Who it would put together is said in icons, never in words: one disc per member, the
                // output in use first, clear of the planet; the names and the click's meaning come with the pointer
                const icons = h.view().children.find(c => "glyphOf" in c);
                const at = icons.mapToItem(scene, 0, 0);
                const dx = Math.max(at.x - g.px, 0, g.px - (at.x + icons.width)), dy = Math.max(at.y - g.py, 0, g.py - (at.y + icons.height));
                check("its icons: one disc per member in order, no name, clear of the planet", [icons.shown, h.texts(icons), Math.hypot(dx, dy) > g.diameter / 2], [[h.dongle, h.headset], 0, true]);
                icons.named = true;
                check("the pointer on it: the names, one line each, and what a click does", [h.texts(icons), icons.note], [3, "Listen together"]);
                icons.named = false;
            }
        },
        {
            // A right click turns it down: remembered by its set, the ring gets its slot back
            "until": () => scene.settled,
            "run": () => {
                h.key = scene.ghost.key;
                h.clickGhost(Qt.RightButton);
                check("a right click turns it down", [route.together.isDeclined(h.key), scene.ghost.offered, route.sharing], [true, false, []]);
            }
        },
        {
            "until": () => scene.settled,
            "run": () => {
                check("it is gone: nothing is loaded and the ring is even again", [scene.world.ghostView.item, h.even(h.ringGaps(), 5)], [null, true]);
                // The same set stays turned down, another set is a new proposal
                route.audio = [route.headset, route.known(h.one)];
            }
        },
        {
            "until": () => scene.settled,
            "run": () => {
                const g = scene.ghost;
                check("counter-proof: a third device is connected, and the pair that was turned down stays down", [g.offered, g.proposal.members], [false, [h.dongle, h.headset]]);
                h.learn([h.dongle, h.headset, h.one]);
                check("a learned group is another set: it is proposed whole, the output in use first", [g.offered, g.proposal.members], [true, [h.dongle, h.headset, h.one]]);
                check("(its own key)", g.key !== h.key, true);
                const key = g.key;
                route.audio = [route.known(h.one), route.headset];
                check("the same devices in another order are the same proposal", [g.key, g.proposal.members], [key, [h.dongle, h.headset, h.one]]);
                route.audio = [route.headset];
                check("counter-proof: back to the set that was turned down, it stays down", [g.key, g.offered], [h.key, false]);
                route.audio = [route.headset, route.known(h.one)];
            }
        },
        {
            // The cross is a click of its own: it does not start the group below it
            "until": () => scene.settled,
            "run": () => {
                // Read before the click: once it is turned down the best learned group leaves nothing to propose
                const shown = scene.ghost.key;
                h.clickCross();
                check("the cross turns it down, and starts nothing", [shown !== "", route.together.isDeclined(shown), scene.ghost.offered, route.sharing], [true, true, false, []]);
                route.audio = [route.headset, route.known(h.one), route.known(h.two)];
                h.learn([h.dongle, h.headset, h.one, h.two]);
            }
        },
        {
            // A click makes the group
            "until": () => scene.settled,
            "run": () => {
                const g = scene.ghost;
                check("a fresh set is offered", [g.offered, g.proposal.members], [true, [h.dongle, h.headset, h.one, h.two]]);
                scene.hiddenOpen = true;
                h.clickGhost(Qt.LeftButton);
                check("counter-proof: with the hidden list open a click starts nothing", route.sharing, []);
                scene.hiddenOpen = false;
                h.clickGhost(Qt.LeftButton);
                check("a click starts the group with what the ghost showed", route.sharing, [h.dongle, h.headset, h.one, h.two]);
                check("the ghost is no longer offered", g.offered, false);
            }
        },
        {
            "until": () => scene.settled,
            "run": () => {
                check("never during a session: the group has the centre and nothing is left of the ghost", [scene.centre.grouped, scene.ghost.shown, scene.world.ghostView.item], [true, false, null]);
                route.sharing = [];
            }
        },
        {
            "wait": 100,
            "run": () => {
                check("the session is over and nothing turned it down: it is proposed again", [scene.centre.grouped, scene.ghost.offered, scene.ghost.shown], [false, true, true]);
            }
        },
        {
            // A closed orbit keeps nothing
            "wait": 300,
            "run": () => {
                scene.active = false;
            }
        },
        {
            "until": () => scene.ghost.placed,
            "run": () => {
                check("the orbit is closed: no ghost, nothing loaded", [scene.ghost.offered, scene.ghost.shown, scene.world.ghostView.item], [false, false, null]);
                scene.active = true;
            }
        },
        {
            // The orbit turns for a moment
            "until": () => scene.orbitTime > h.orbit + 0.3,
            "run": () => {
                check("opened again: it is back", [scene.ghost.offered, scene.world.ghostView.item !== null], [true, true]);
                // Motion on: the ghost rides the ring with the others, and the loop runs
                h.orbit = scene.orbitTime;
                h.before = {
                    "x": scene.ghost.px,
                    "y": scene.ghost.py
                };
                SettingsData.reduceMotion = false;
                scene.wake();
            }
        },
        {
            // The loop stops by itself, with the ghost still on the ring
            "until": () => h.settledSeen,
            "run": () => {
                const g = scene.ghost;
                check("motion on: the loop runs and the ghost goes round with the ring", [scene.settled, scene.orbitTime > h.orbit, Math.hypot(g.px - h.before.x, g.py - h.before.y) > 0.5], [false, true, true]);
                SettingsData.reduceMotion = true;
                scene.wake();
                h.settledSeen = false;
                settleProbe.start();
            }
        },
        {
            "wait": 0,
            "run": () => {
                settleProbe.stop();
                check("Reduce motion again: the ring stops and so does the loop", [h.settledSeen, scene.ghost.offered], [true, true]);
            }
        },
        {
            // A press held 500 ms acts as a right click (NAK-10, D368): released early it is a plain click
            "wait": 0,
            "run": () => {
                const p = scene.ghost, z = h.view().pointer;
                h.key = p.key;
                mouse.mousePress(scene, p.px, p.py);
                mouse.wait(250);
                check("held 250 ms: the ring is filling, nothing decided yet", [z.children.find(c => "fired" in c).active, p.offered, route.together.isDeclined(h.key)], [true, true, false]);
                mouse.mouseMove(scene, p.px + 12, p.py);
                const hold = z.children.find(c => "fired" in c);
                mouse.wait(450);
                // Let go well outside the disc, so that no click follows
                mouse.mouseMove(scene, p.px + 200, p.py);
                mouse.mouseRelease(scene, p.px + 200, p.py);
                check("counter-proof: moved past the threshold, the hold is cancelled and nothing is turned down", [hold.active, p.offered, route.together.isDeclined(h.key)], [false, true, false]);
                mouse.mousePress(scene, p.px, p.py);
                mouse.wait(650);
                check("held 500 ms: it is turned down, like a right click", [route.together.isDeclined(h.key), p.offered], [true, false]);
                mouse.mouseRelease(scene, p.px, p.py);
                check("the release after the long press starts no group", route.sharing, []);
            }
        }
    ]
    property int step: 0
    property double stepStart: 0
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 120000
        running: true
        onTriggered: {
            print("FAIL timed out at step " + h.step);
            Qt.exit(1);
        }
    }
    Timer {
        id: clock
        interval: 50
        repeat: true
        onTriggered: {
            const s = h.steps[h.step - 1], waited = Date.now() - h.stepStart;
            if (s.until ? s.until() || waited > 10000 : waited >= s.wait)
                h.next();
        }
    }
    function next() {
        clock.stop();
        if (step >= steps.length) {
            print(failures ? failures + " failure(s)" : "all passed");
            Qt.exit(failures ? 1 : 0);
            return;
        }
        steps[step++].run();
        stepStart = Date.now();
        clock.start();
    }
    Component.onCompleted: {
        PluginService.globalVars = State.globals("orbit", Date.now());
        alone();
        other();
        h.pipewire(null, []);
        Qt.callLater(next);
    }
}
