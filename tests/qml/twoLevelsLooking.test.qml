import QtQuick
import qs.Common
import "components/volume"
import "mock"

// Test of what TwoLevels reads while the pop-up shows (NAK-210, D272): the
// audio facts (pactl) start when someone looks, not when the scope merely
// listens, so a burst of volume keys does not start them with its first key.
// Run with tests/qml/run.sh.
Item {
    id: h

    FakeRoute {
        id: route
    }
    QtObject {
        id: prefs
        property var factsLine: ({
                "connection": true
            })
        property var factsMore: ({})
        property string scopeStyle: "points"
        property int scopeFps: 30
        property bool reduceMotion: false
    }
    TwoLevels {
        id: levels
        route: route
        prefs: prefs
    }

    Tally {
        id: tally
    }
    // The facts reader (the only child with a `pcSink`)
    function facts() {
        for (let i = 0; i < levels.data.length; i++)
            if ("pcSink" in levels.data[i])
                return levels.data[i];
        return null;
    }

    Component.onCompleted: {
        tally.check("the facts reader exists", facts() !== null, true);
        tally.check("hidden: nothing is read", facts().active, false);

        // The pop-up is up and the scope listens, but a burst of keys holds
        // the rest back (an owner sets looking from its settle timer)
        levels.listening = true;
        levels.looking = false;
        tally.check("listening alone starts no read", facts().active, false);
        levels.looking = true;
        tally.check("looking, with a fact chosen: the facts are read", facts().active, true);
        levels.looking = false;
        tally.check("the burst starts again: the reading stops", facts().active, false);

        tally.finish();
    }
}
