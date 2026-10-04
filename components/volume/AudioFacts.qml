import QtQuick
import Quickshell.Io
import "Audiophile.js" as Audiophile

// What the output in view is (D260): connection, codec, rate, depth. Asks
// PipeWire's own tool for the listing once when it starts being `active`
// (a view is on screen and the user shows some fact), and again on
// `refresh()`; the listing is dropped when nothing looks at it. The command
// is fixed: no user data reaches it. Nothing runs while inactive.
Item {
    id: root
    objectName: "audioFacts" // found by the offscreen previews

    property bool active: false
    // The sinks to describe: the output itself, and this PC's filter in
    // front of it (empty without one)
    property string sink: ""
    property string pcSink: ""

    // The facts of `sink` and of `pcSink`, null until read
    readonly property var facts: _all[sink] ?? null
    readonly property var pcFacts: pcSink ? (_all[pcSink] ?? null) : null
    property var _all: ({})

    function refresh() {
        if (active && sink && !reader.running)
            reader.running = true;
    }
    onActiveChanged: {
        if (active)
            refresh();
        else
            _all = ({});
    }
    onSinkChanged: refresh()
    onPcSinkChanged: refresh()

    Process {
        id: reader
        command: ["pactl", "--format=json", "list", "sinks"]
        stdout: StdioCollector {
            id: listing
        }
        onExited: code => root._all = code === 0 ? Audiophile.parse(listing.text) : ({})
    }
}
