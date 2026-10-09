import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "components/volume"

// Test of the keys' target in AudioRoute outside a group (NAK-196, D379): the
// last level that changed is the target, whichever way it changed (the
// headset's buttons, anything else on the PC, a level set in Orbit), and it
// stays when the output you hear changes. Fake outputs whose level moves by a
// plain assignment stand for the headsets; what Orbit and the keys write
// themselves comes back as an echo and never picks. Made-up addresses only.
// Run with tests/qml/run.sh.
Item {
    id: h

    component Sink: QtObject {
        required property string name
        readonly property bool isSink: true
        readonly property bool isStream: false
        readonly property bool ready: true
        readonly property QtObject audio: QtObject {
            property real volume: 0.5
            property bool muted: false
        }
    }
    readonly property string one: "AA:BB:CC:DD:EE:01"
    readonly property string two: "AA:BB:CC:DD:EE:02"
    Sink {
        id: s1
        name: "bluez_output.AA_BB_CC_DD_EE_01.1"
    }
    Sink {
        id: s2
        name: "bluez_output.AA_BB_CC_DD_EE_02.1"
    }
    // The virtual sink Orbit runs in front of the second headset: this PC's level
    Sink {
        id: p2
        name: "orbit_pc_AA_BB_CC_DD_EE_02"
    }
    Device {
        id: d1
        address: h.one
        name: "Fictional One"
        connected: true
    }
    Device {
        id: d2
        address: h.two
        name: "Fictional Two"
        connected: true
    }

    QtObject {
        id: prefs
        property bool volumeTick: false
        property bool tickAlone: true
        property bool separatePc: true
        property var pcLevels: ({})
        property string volumeSteps: "fixed"
        property int volumeStep: 5
        property string volumeSpeed: "balanced"
        property int togetherFineDelay: 0
    }
    AudioRoute {
        id: route
        prefs: prefs
        // The test cannot wait for a node to settle
        settleMs: 0
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function pct(node) {
        return Math.round(node.audio.volume * 100);
    }

    Component.onCompleted: {
        Pipewire.extraSinks = [s1, s2, p2];
        Pipewire.defaultAudioSink = s1;
        Bluetooth.devices = [d1, d2];
        route.known(one).absolute = 1;
        route.known(two).absolute = 1;
        check("two headsets with their own level", [route.ownNode(one) === s1, route.ownNode(two) === s2], [true, true]);
        check("the first plays", route.current.address, one);
        check("at rest: the output you hear, nothing marked", [route.target, route.marked], ["", ""]);

        // Another headset's own buttons, or anything else on the PC
        s2.audio.volume = 0.7;
        check("a foreign change on a headset that does not play: it is the target", route.target, two);
        check("and it is marked, as the output you hear is another", route.marked, two);
        check("the active output did not change", Pipewire.defaultAudioSink === s1, true);
        check("the keys step the target", route.stepHeard(1), "");
        check("it moved by a step", [pct(s2), pct(s1)], [75, 50]);
        check("the echo of the keys does not re-pick", [route.target, route.touched], [two, two]);
        route.writeLevel(s1, 0.4);
        check("Orbit writing another level is an echo, not a change of target", route.target, two);

        // The playing headset's own buttons: the target is the output you hear
        s1.audio.volume = 0.6;
        check("the playing headset picks itself", route.target, one);
        check("nothing is marked when the target is the output you hear", route.marked, "");

        // The output you hear changes: the target stays
        Pipewire.defaultAudioSink = s2;
        check("a new output you hear: the target stays", route.target, one);
        check("and is marked, now that it is not the one you hear", route.marked, one);
        check("the keys still step it", [route.stepHeard(-1), pct(s1), pct(s2)], ["", 55, 75]);

        // A level set in Orbit or by `deviceVolume` picks it
        check("a level set by command", route.setLevel("device", "30", two), "");
        check("it becomes the target", [route.target, route.marked, pct(s2)], [two, "", 30]);

        // This PC's level
        p2.audio.volume = 0.8;
        check("this PC's level moved elsewhere: the target", route.target, "pc");
        check("it is the output's own, so never marked", route.marked, "");
        route.stepHeard(1);
        check("the keys step this PC's level, not the headset's own", [pct(p2), pct(s2)], [85, 30]);
        s2.audio.volume = 0.2;
        check("the headset's own level takes the target back", route.target, two);

        // A headset that disconnects: back to the output you hear
        route.touch(one);
        check("the first is the target", route.target, one);
        d1.connected = false;
        Pipewire.extraSinks = [s2, p2];
        check("it left: the keys go back to the output you hear", [route.target, route.touched], ["", ""]);
        Pipewire.extraSinks = [s1, s2, p2];
        d1.connected = true;
        route.known(one).absolute = 1;
        check("and it does not come back by itself", route.target, "");

        // A group playing is another matter (D378)
        route.touch(two);
        route.together.members = [one, two];
        check("a group starts: the target is the group's again", [route.touched, route.target], ["", ""]);
        s1.audio.volume = 0.9;
        check("in the group: the member's own change picks it, as before", route.target, one);
        route.together.members = [];
        check("the group ends: back to the output you hear", [route.touched, route.target], ["", ""]);
        Qt.exit(failures === 0 ? 0 : 1);
    }
}
