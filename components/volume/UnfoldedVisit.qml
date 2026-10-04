import QtQuick

// The audio details' unfolded state, one for every screen that shows them.
// They are for the visit they were asked in: a pop-up (and the island sheet,
// which keeps its screen) opens folded every time. A visit starts when the
// first screen shows the scope and ends when the last one leaves, so a
// screen closing while another still shows the details does not fold them
// under it, and details already unfolded when the visit began are left as
// they were. Never write the line's own `expanded`: it would cut its link.
QtObject {
    id: visit

    property bool unfolded: false
    // Screens showing the scope now
    property int _screens: 0
    property bool _startedFolded: true

    // A screen starts or stops showing the scope (ScopeScreen.live)
    function screenShown(on) {
        if (on) {
            if (_screens++ === 0)
                _startedFolded = !unfolded;
        } else if (--_screens === 0 && _startedFolded) {
            unfolded = false;
        }
    }
}
