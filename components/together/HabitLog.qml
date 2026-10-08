import QtQuick
import "Habits.js" as Habits

// Teaches the ghost group which outputs the user listens to together (D299).
// A group counts as used once its members stayed the same for a minute of a
// session (Habits.MIN_USE_MS), so the group the user ends up with is what is
// learned: taking a member out right after the group was made leaves the
// group without it as the one that counts. The time is read when the members
// change, the session ends or the shell stops, never by a timer: at rest this
// holds one number.
// Switching learning off erases the memory at once, and nothing is recorded
// while it is off (value 5).
QtObject {
    id: log

    // The daemon's TogetherSession (members, active) and Prefs (learnHabits,
    // togetherHabits, set)
    required property var session
    required property var prefs
    // The time in ms, replaced by a test
    property var clock: Date.now

    // The group in force and when it formed (0 while there is none)
    property var _members: []
    property double _since: 0

    // The group in force counts once, if it lasted long enough
    function _count(now) {
        if (prefs.learnHabits && _since > 0 && now - _since >= Habits.MIN_USE_MS)
            prefs.set("togetherHabits", Habits.record(prefs.togetherHabits, _members, now));
    }

    function _settle() {
        const now = log.clock();
        _count(now);
        _members = session.active ? session.members : [];
        _since = session.active ? now : 0;
    }

    property Connections _watch: Connections {
        target: log.session
        function onMembersChanged() {
            log._settle();
        }
    }

    // Learning is off but something is left (it was just switched off, or the
    // settings were edited by hand): erased once, as the button does
    function _sweep() {
        if (!prefs.learnHabits && Habits.count(prefs.togetherHabits) > 0)
            prefs.set("togetherHabits", Habits.forget());
    }
    property Connections _switch: Connections {
        target: log.prefs
        function onLearnHabitsChanged() {
            log._sweep();
        }
    }
    Component.onCompleted: _sweep()
    // A session still going when the shell stops (a restart, a reload) is
    // counted too: it would never see its end otherwise. Once, at the very
    // end, so there is still no timer at rest.
    Component.onDestruction: _count(log.clock())
}
