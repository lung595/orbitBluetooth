import QtQuick

// The radar's one clock: a Timer of about 60 Hz that runs only while something of
// the radar moves (`busy`) and says how long each step lasted. Nothing else of the
// radar animates (a QML animation repaints the whole shell at the screen's rate),
// so at rest, or with Reduce motion, this costs nothing.
Item {
    id: clock

    // Something still moves: the view says so from what it knows is on its way
    property bool busy: false
    // Reduce motion turns it off for good
    property bool motion: true
    readonly property bool running: busy && motion

    // A step of `dt` seconds
    signal tick(real dt)

    property double _last: 0

    Timer {
        interval: 16
        repeat: true
        running: clock.running
        onRunningChanged: {
            if (running)
                clock._last = Date.now();
        }
        onTriggered: {
            const now = Date.now();
            const dt = Math.min(0.1, (now - clock._last) / 1000);
            clock._last = now;
            clock.tick(dt);
        }
    }
}
