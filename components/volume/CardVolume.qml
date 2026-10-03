import QtQuick
import Quickshell.Io
import "Volume.js" as Volume

// The two volumes of the device on the detail card (D250): TwoLevels for
// the card's device, a note when it has no level of its own (D249), the
// tick played in the device on each 5 % step, and the card's own picture
// of the sound, which runs only while the card is `live`: nothing at rest.
TwoLevels {
    id: root

    property string address: ""
    property bool live: false

    dev: route && address ? route.find(address) : null
    // The device plays through PipeWire: there is something to show
    readonly property bool ready: !!dev
    // The card's own picture of the sound (the pop-up has its own)
    soundNode: dev ? dev.sink : null
    listening: live && ready

    // No level of its own: say why, with the guide's link (value 10)
    readonly property var note: ready && !deviceAudio ? {
        "text": "Its volume follows this PC",
        "action": "",
        "anchor": "the-two-volumes"
    } : null
    function noteAction() {
    }

    // --- The tick, played in the device on each 5 % step --------------------------
    readonly property string tickPath: decodeURIComponent(Qt.resolvedUrl("../../sounds/volume.wav").toString().replace(/^file:\/\//, ""))
    property double _lastTick: 0
    onLevelMoved: (before, after) => {
        const sink = dev ? dev.sink : null;
        if (!prefs || !prefs.volumeTick || !sink || !Volume.validSink(sink.name))
            return;
        if (Volume.step(before) === Volume.step(after))
            return;
        // A fast wheel must not stack sounds: one tick per 45 ms at most
        const now = Date.now();
        if (now - _lastTick < 45 || player.running)
            return;
        _lastTick = now;
        player.command = ["pw-play", "--target", sink.name, "--", tickPath];
        player.running = true;
    }
    Process {
        id: player
    }
}
