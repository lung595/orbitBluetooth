import QtQuick
import Quickshell.Io
import "../volume/AudioGraph.js" as Graph
import "Delay.js" as Delay

// What each member of a Listen together session adds before it is heard
// (D298), read from PipeWire's graph with one `pw-dump`. It is read when the
// session forms and again when a member's output changes (the members, a
// codec, a profile: `signature`), a moment later so that a burst of changes is
// one read. Never polled. The command is fixed, no user data reaches it, and
// the item exists only while a session does (TogetherSession), so nothing runs
// and nothing is kept outside one. The figures only feed the automatic wait of
// the wired outputs (Delay.js).
Item {
    id: root

    // The sink each member plays on, { member: node name }
    property var sinks: ({})
    // A text that changes when a figure may have changed (a codec, a profile)
    property string signature: ""

    // { member: ms } for the members the graph gave a figure for (Delay.latenciesOf)
    property var latencies: ({})

    // A change that came while the read ran: read again afterwards
    property bool _again: false

    Component.onCompleted: settle.restart()
    onSignatureChanged: settle.restart()

    // Starts only when asked, and stops after one tick
    Timer {
        id: settle
        interval: 400
        onTriggered: {
            if (dumper.running)
                root._again = true;
            else
                dumper.running = true;
        }
    }

    Process {
        id: dumper
        command: ["pw-dump"]
        stdout: StdioCollector {
            id: dumped
        }
        onExited: code => {
            if (code === 0)
                root.latencies = Delay.latenciesOf(root.sinks, Graph.parseDump(dumped.text));
            // Through the timer: the process is surely over by then
            if (root._again) {
                root._again = false;
                settle.restart();
            }
        }
    }
}
