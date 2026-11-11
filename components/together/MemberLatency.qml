import QtQuick
import Quickshell.Io
import qs.Common
import "../common"
import "../volume/AudioGraph.js" as Graph
import "Delay.js" as Delay

// What each member of a Listen together session adds before it is heard
// (D298), read from PipeWire's graph with WirePlumber's `wpexec` and a fixed,
// read-only script (graph/orbit_graph.lua; pw-dump comes with pipewire-utils,
// which a default install lacks). It is read when the session forms and again
// when a member's output changes (the members, a codec, a profile:
// `signature`), a moment later so that a burst of changes is one read, then it
// stops (D368). Never polled. The command is fixed, no user data reaches it,
// and the item exists only while a session does (TogetherSession), so nothing
// runs and nothing is kept outside one. The figures feed the automatic wait of
// the copies (Delay.js).
Item {
    id: root

    // The sink each member plays on, { member: node name }
    property var sinks: ({})
    // A text that changes when a figure may have changed (a codec, a profile)
    property string signature: ""

    // { member: ms } for the members the graph gave a figure for (Delay.latenciesOf)
    property var latencies: ({})
    // A read is over and `latencies` holds its figures (also when it gave none)
    signal measured

    // A change that came while the read ran: read again afterwards
    property bool _again: false
    // The reader, beside this plugin's other helpers
    readonly property string _script: Paths.strip(Qt.resolvedUrl("../../graph/orbit_graph.lua"))

    // A read is over with these figures: the group is told, unless a change
    // came meanwhile, which reads again
    function _over(figures) {
        latencies = figures;
        if (!_again)
            measured();
        // Through the timer: the process is surely over by then
        if (_again) {
            _again = false;
            settle.restart();
        }
    }

    Component.onCompleted: settle.restart()
    onSignatureChanged: settle.restart()

    // Starts only when asked, and stops after one tick
    Timer {
        id: settle
        interval: 400
        onTriggered: {
            if (dumper.running) {
                root._again = true;
            } else {
                dumper.launch(["wpexec", root._script]);
            }
        }
    }

    // ToolProcess: one `finished` per read, -1 when wpexec could not start
    // (no WirePlumber), so the group is told then too, never left waiting
    ToolProcess {
        id: dumper
        stdout: StdioCollector {
            id: dumped
        }
        // A failed read leaves every figure unknown: none is kept from an
        // earlier read, and the group is told as well
        onFinished: code => root._over(code === 0 ? Delay.latenciesOf(root.sinks, Graph.parseDump(dumped.text)) : ({}))
    }
}
