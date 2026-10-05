import QtQuick
import Quickshell.Io
import "Wired.js" as Wired

// The wired outputs plugged in right now (D298), for the group chooser and the
// ghost group. Asks PipeWire's own tool for the listing once when it becomes
// `active` (a view that needs the list is on screen) and again on `refresh()`;
// the list is dropped when nothing needs it. The command is fixed
// (Wired.command): no user data reaches it. Nothing runs while inactive.
Item {
    id: root
    objectName: "wiredWatch" // found by the offscreen previews

    property bool active: false
    // The plugged wired outputs, sorted: [{ sink, label, bus, formFactor, plugged }]
    property var outputs: []

    function refresh() {
        if (active && !reader.running)
            reader.running = true;
    }
    onActiveChanged: {
        if (active)
            refresh();
        else
            outputs = [];
    }

    Process {
        id: reader
        command: Wired.command()
        stdout: StdioCollector {
            id: listing
        }
        onExited: code => {
            const next = code === 0 ? Wired.parse(listing.text) : [];
            // The same outputs again: nothing downstream has to react
            if (!Wired.sameSet(root.outputs, next))
                root.outputs = next;
        }
    }
}
