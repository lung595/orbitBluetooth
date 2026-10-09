import QtQuick
import "components/volume"

// Test of the keys' target in AudioRoute (NAK-9): the last member touched is
// remembered, touching the group (or nothing) clears it, and a member the
// route does not know has no own level, so the keys fall back to the group.
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
        Qt.exit(failures === 0 ? 0 : 1);
    }
}
