import QtQuick
import Quickshell.Services.Pipewire
import "components/volume"

// Test of the keys' target in AudioRoute (NAK-9, NAK-174): the last member
// touched is remembered, touching the group (or nothing) clears it, and a
// member the route does not know has no own level, so the keys fall back to
// the group. A fake output whose level changes by itself stands for a headset
// moving its volume with its buttons: that member becomes the target and stays
// (nothing closes it), while what Orbit and the keys write never does.
// Made-up addresses only. Run with tests/qml/run.sh.
Item {
    id: h

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
    }

    // Two wired outputs; their levels move with a plain assignment, like a
    // headset reporting its buttons (a wired output has no virtual sink here)
    Component {
        id: fakeOutput
        QtObject {
            required property string name
            readonly property bool isSink: true
            readonly property bool isStream: false
            readonly property bool ready: true
            readonly property QtObject audio: QtObject {
                property real volume: 0.5
                property bool muted: false
            }
        }
    }
    readonly property string one: "alsa_output.fictional-one"
    readonly property string two: "alsa_output.fictional-two"

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    Component.onCompleted: {
        check("at rest: the group", route.touched, "");
        route.touch("AA:01");
        check("a member touched: remembered", route.touched, "AA:01");
        route.touch("AA:02");
        check("another member: replaces it", route.touched, "AA:02");
        route.touch("");
        check("the group touched: cleared", route.touched, "");
        check("an unknown member has no own level", route.ownNode("AA:09"), null);
        check("so the keys move the group, not a node of it", route.stepHeard(1), "no-pc-level");
        check("no group: nothing is lit", route.target, "");

        // A group starting clears a touch made before it, and the group
        // ending clears the member that was touched in it
        route.touch("AA:01");
        route.together.members = ["AA:01", "AA:02"];
        check("a group starts: a stale touch is dropped", route.touched, "");
        route.touch("AA:02");
        check("in the group: the member is remembered", route.touched, "AA:02");
        route.together.members = [];
        check("the group ends: back to the group", route.touched, "");

        // The headset's buttons (NAK-174)
        const a = fakeOutput.createObject(h, {
            "name": one
        });
        const b = fakeOutput.createObject(h, {
            "name": two
        });
        Pipewire.extraSinks = [a, b];
        route.together.members = [one, two];
        check("a group of two outputs plays", route.together.active, true);
        check("it starts on the group", route.target, "");
        a.audio.volume = 0.55;
        check("the first read is not a change; a button press picks the member", route.target, one);
        b.audio.volume = 0.7;
        check("the other member's buttons replace it", route.target, two);
        check("it stays: nothing is reset by time or by closing", route.touched, two);

        // The keys write the target's node; the node reports it back at once
        check("the keys step the target", route.stepHeard(1), "");
        check("its level moved by a step", Math.round(b.audio.volume * 100), 75);
        check("the echo of the keys does not re-pick", route.target, two);
        route.touch(one);
        route.stepHeard(1);
        route.stepHeard(1);
        check("repeated presses do not flip the target", route.target, one);
        check("the pressed member moved, the other did not", [Math.round(a.audio.volume * 100), Math.round(b.audio.volume * 100)], [65, 75]);

        // The group's level written by Orbit, the members keeping their gaps
        route.touch("");
        route.writeLevels([a, b], [0.3, 0.4], 0.5, 0.35);
        check("the group's level by Orbit is not the headset", route.target, "");
        a.audio.volume = 0.9;
        check("a button press after the group's level picks the member", route.target, one);

        // A member's node going away and back is a new read, not a change
        Pipewire.extraSinks = [b];
        check("a member without its node falls back to the group", route.target, "");
        Pipewire.extraSinks = [a, b];
        check("and coming back is not a button press", route.touched, one);
        route.touch("");
        route.together.members = [];
        check("the group ends: back to the group", route.touched, "");
        a.audio.volume = 0.1;
        check("outside a group nobody listens", route.touched, "");
        Qt.exit(failures === 0 ? 0 : 1);
    }
}
