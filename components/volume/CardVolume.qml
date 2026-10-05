import QtQuick

// The two volumes of the device on the detail card (D250): TwoLevels for
// the card's device, a note when it has no level of its own (D249), and the
// card's own picture of the sound, which runs only while the card is `live`:
// nothing at rest. The tick on each 5 % step is the route's (VolumeTick).
TwoLevels {
    id: root

    property string address: ""
    property bool live: false
    // The card is on screen, folded volume or not (the facts line shows)
    property bool seen: false

    dev: route && address ? route.find(address) : null
    // The device plays through PipeWire: there is something to show
    readonly property bool ready: !!dev
    // The card's own picture of the sound (the pop-up has its own)
    soundNode: dev ? dev.sink : null
    listening: live && ready
    looking: seen && ready

    // No level of its own: say why, with the guide's link (value 10)
    readonly property var note: ready && !split && !deviceAudio ? {
        "text": "Its volume follows this PC",
        "action": "",
        "anchor": "the-two-volumes"
    } : null
    function noteAction() {
    }
}
