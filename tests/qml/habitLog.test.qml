import QtQuick
import "components/together"
import "components/together/Habits.js" as Habits

// Test of what the ghost group learns (D299): a group counts as used once its
// members stayed the same for a minute of a session, measured by the time
// taken when the members change or the session ends (no timer); the group the
// user ends up with is what is learned; only hashes are written; and with
// learning off nothing is recorded and what is left is erased at once. The
// session and the settings are made up, the clock is the test's. Run with
// tests/qml/run.sh.
Item {
    id: h

    readonly property string a: "02:00:00:00:30:01"
    readonly property string b: "02:00:00:00:30:02"
    readonly property string c: "02:00:00:00:30:03"
    readonly property string wired: "alsa_output.usb-Acme_Studio-00.analog-stereo"

    Tally {
        id: tally
    }

    // The part of TogetherSession the log reads
    QtObject {
        id: session
        property var members: []
        readonly property bool active: members.length >= 2
    }
    // The part of Prefs it reads and writes: every write is kept, as the shell would save it
    QtObject {
        id: prefs
        property bool learnHabits: true
        property var togetherHabits: ({})
        property var writes: []
        function set(key, value) {
            writes = writes.concat([[key, value]]);
            if (key === "togetherHabits")
                togetherHabits = value;
        }
    }
    property double now: 1000000000000
    Component {
        id: logComponent
        HabitLog {
            session: h.fakeSession
            prefs: h.fakePrefs
            clock: () => h.now
        }
    }
    // The ids, reachable from inside the component (a property of the same name hides them there)
    readonly property var fakeSession: session
    readonly property var fakePrefs: prefs
    HabitLog {
        id: log
        session: session
        prefs: prefs
        clock: () => h.now
    }

    // Time goes by (s) with the members as they are
    function wait(seconds) {
        now += seconds * 1000;
    }
    function groups() {
        return Object.values(prefs.togetherHabits);
    }

    Component.onCompleted: {
        tally.check("at rest nothing is written", prefs.writes, []);

        // A group kept for a minute counts, once the session ends
        session.members = [a, b];
        wait(61);
        tally.check("it counts only when the members change or the session ends: nothing yet", prefs.writes.length, 0);
        session.members = [];
        tally.check("the session ends after a minute: one group, one use", [groups().length, groups()[0].n], [1, 1]);
        tally.check("only hashes are written: no address, no name", JSON.stringify(prefs.writes).match(/30:0|02:00|alsa|Acme/), null);
        tally.check("the group is the one that was kept", Object.keys(prefs.togetherHabits), [Habits.keyOf([a, b])]);

        // Counter-proof: less than a minute teaches nothing
        const writes = prefs.writes.length;
        session.members = [a, c];
        wait(59);
        session.members = [];
        tally.check("counter-proof: a group that ended before a minute is not learned", [prefs.writes.length, Object.keys(prefs.togetherHabits).length], [writes, 1]);

        // The group the user ends up with is what counts (a member taken out right after the group was made)
        session.members = [a, b, c];
        wait(5);
        session.members = [a, b];
        wait(120);
        session.members = [];
        tally.check("a member taken out within seconds: the group without it is learned, the first one is not", [Object.keys(prefs.togetherHabits).sort(), prefs.togetherHabits[Habits.keyOf([a, b])].n], [[Habits.keyOf([a, b])], 2]);
        tally.check("(the group with all three was never kept for a minute)", prefs.togetherHabits[Habits.keyOf([a, b, c])], undefined);

        // A wired output is a member like the others
        session.members = [a, wired];
        wait(300);
        session.members = [a, wired, b];
        wait(70);
        session.members = [];
        tally.check("a group that grows is two groups, each kept long enough", Object.keys(prefs.togetherHabits).length, 3);
        tally.check("a wired output's name is not written either", JSON.stringify(prefs.writes).match(/alsa|Acme|Studio/), null);

        // Learning off: nothing is recorded, and what was learned is erased at once
        prefs.learnHabits = false;
        tally.check("learning off erases what was learned, at once", [prefs.togetherHabits, prefs.writes[prefs.writes.length - 1]], [
            {},
            ["togetherHabits",
                {}
            ]]);
        const after = prefs.writes.length;
        session.members = [a, b];
        wait(600);
        session.members = [];
        tally.check("counter-proof: with learning off nothing is recorded, however long the group lasts", [prefs.writes.length, prefs.togetherHabits], [after,
            {}
        ]);

        // Back on, it learns again from nothing
        prefs.learnHabits = true;
        session.members = [b, c];
        wait(90);
        session.members = [];
        tally.check("on again: it starts afresh", [groups().length, groups()[0].n], [1, 1]);

        // The same group the other way round is the same group
        session.members = [c, b];
        wait(90);
        session.members = [];
        tally.check("the same members in another order are the same group", [groups().length, groups()[0].n], [1, 2]);

        // A session replaced by another with the same members is closed first
        session.members = [b, c];
        wait(90);
        session.members = [c, b];
        tally.check("a session started again with the same members: the first one counted", groups()[0].n, 3);
        session.members = [];

        // A session still going when the shell stops is counted; one too short is not.
        // destroy() runs on the next event loop turn, so the checks wait for it
        const before = groups()[0].n;
        const stopping = logComponent.createObject(h);
        const brief = logComponent.createObject(h);
        session.members = [b, c];
        wait(90);
        stopping.destroy();
        Qt.callLater(() => {
            tally.check("a session still active when the shell stops is counted", groups()[0].n, before + 1);
            const writesNow = prefs.writes.length;
            // Back to 10 s into the session: too short to count
            wait(-80);
            brief.destroy();
            Qt.callLater(() => {
                tally.check("counter-proof: a session shorter than a minute is not counted at the stop", prefs.writes.length, writesNow);
                finish();
            });
        });
    }

    function finish() {
        Qt.callLater(() => {
            tally.finish();
        });
    }
}
