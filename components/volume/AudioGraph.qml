import QtQuick
import Quickshell.Io
import "AudioGraph.js" as Graph

// What PipeWire's graph says of the output in view (D260): the delay it
// reports, LDAC's quality and the quantum the graph runs at. Each command
// runs once, when its fact starts being wanted (`wantDump` / `wantTop`) and again
// on `refresh()`, and its answer is dropped (or ignored, if it ends late)
// as soon as it is not wanted:
// nothing polls and nothing runs while folded. The commands are fixed, no
// user data reaches them. `pw-top` samples for one second, then ends.
Item {
    id: root
    objectName: "audioGraph" // found by the offscreen previews

    // Which commands are wanted (Audiophile.needs)
    property bool wantDump: false
    property bool wantTop: false
    property string sink: ""

    // What is known of `sink`: latencyMs, quality, quantum, quantumRate
    readonly property var facts: Object.assign({}, _dumped[sink], _topped[sink])
    property var _dumped: ({})
    property var _topped: ({})

    function refresh() {
        if (wantDump && sink && !dumper.running)
            dumper.running = true;
        if (wantTop && sink && !sampler.running)
            sampler.running = true;
    }
    onWantDumpChanged: {
        if (wantDump)
            refresh();
        else
            _dumped = ({});
    }
    onWantTopChanged: {
        if (wantTop)
            refresh();
        else
            _topped = ({});
    }
    onSinkChanged: refresh()

    Process {
        id: dumper
        command: ["pw-dump"]
        stdout: StdioCollector {
            id: dumped
        }
        onExited: code => root._dumped = root.wantDump && code === 0 ? Graph.parseDump(dumped.text) : ({})
    }
    // Two iterations: the first one has nothing to compare with
    Process {
        id: sampler
        command: ["pw-top", "-b", "-n", "2"]
        stdout: StdioCollector {
            id: sampled
        }
        onExited: code => root._topped = root.wantTop && code === 0 ? Graph.parseTop(sampled.text) : ({})
    }
}
