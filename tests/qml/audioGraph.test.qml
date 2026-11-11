import QtQuick
import "components/volume"

// Test of AudioGraph: nothing runs until a command is wanted and a sink is
// named (value 6); each command runs for its own fact only; an answer is
// dropped as soon as it is not wanted any more, even one that ends late; a
// failed command gives nothing. The commands are fixed, no user data
// reaches them (value 11). Run with tests/qml/run.sh.
Item {
    id: h

    AudioGraph {
        id: graph
        sink: "bluez_output.AA_BB_CC_DD_EE_FF.1"
    }

    // What the graph reader (graph/orbit_graph.lua, pw-dump's shape) and `pw-top -b -n 2` say, cut down to what is read
    readonly property string listing: JSON.stringify([
        {
            "info": {
                "props": {
                    "node.name": "bluez_output.AA_BB_CC_DD_EE_FF.1",
                    "media.class": "Audio/Sink"
                },
                "params": {
                    "Latency": [
                        {
                            "direction": "Input",
                            "maxNs": 606387499
                        }
                    ],
                    "Props": [
                        {
                            "quality": 0
                        }
                    ]
                }
            }
        }
    ])
    readonly property string sample: "S   ID  QUANT   RATE    WAIT    BUSY   W/Q   B/Q  ERR FORMAT           NAME \n" + "S  144      0      0    ---     ---   ---   ---     0                  bluez_output.AA_BB_CC_DD_EE_FF.1\n" + "S   ID  QUANT   RATE    WAIT    BUSY   W/Q   B/Q  ERR FORMAT           NAME \n" + "R  144   1024  96000 739.3us   2.1us  0.07  0.00    0    F32P 2 96000 bluez_output.AA_BB_CC_DD_EE_FF.1\n"

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // The command runner whose command starts with `program`
    function runner(program) {
        for (let i = 0; i < graph.data.length; i++)
            if (graph.data[i].command !== undefined && graph.data[i].command[0] === program)
                return graph.data[i];
        return null;
    }
    // The command ends with this output and exit code
    function finish(program, code, text) {
        const run = runner(program);
        run.stdout.text = text;
        run.running = false;
        run.exited(code);
    }

    Component.onCompleted: {
        check("both runners exist", [runner("wpexec") !== null, runner("pw-top") !== null], [true, true]);
        check("nothing wanted: nothing runs", [runner("wpexec").running, runner("pw-top").running], [false, false]);
        graph.refresh();
        check("asking while nothing is wanted runs nothing", [runner("wpexec").running, runner("pw-top").running], [false, false]);

        graph.wantDump = true;
        check("the dump is wanted: only it runs", [runner("wpexec").running, runner("pw-top").running], [true, false]);
        check("the commands are fixed", [runner("wpexec").command[1].endsWith("/graph/orbit_graph.lua"), runner("wpexec").command.length, runner("pw-top").command], [true, 2, ["pw-top", "-b", "-n", "2"]]);
        finish("wpexec", 0, listing);
        check("the delay and the quality arrive", [graph.facts.latencyMs, graph.facts.quality], [606.387499, 0]);
        check("no quantum without the sampler", graph.facts.quantum, undefined);

        graph.wantTop = true;
        check("the sampler runs once wanted", runner("pw-top").running, true);
        finish("pw-top", 0, sample);
        check("the quantum arrives beside the rest", [graph.facts.quantum, graph.facts.quantumRate, graph.facts.quality], [1024, 96000, 0]);

        graph.wantTop = false;
        check("not wanted: the quantum is dropped, the rest stays", [graph.facts.quantum, graph.facts.latencyMs > 0], [undefined, true]);

        graph.refresh();
        check("a refresh runs only what is wanted", [runner("wpexec").running, runner("pw-top").running], [true, false]);
        graph.wantDump = false;
        finish("wpexec", 0, listing);
        check("an answer that ends late is ignored", graph.facts, ({}));

        graph.wantDump = true;
        finish("wpexec", 1, "garbage");
        check("a failed command gives nothing", graph.facts, ({}));

        graph.sink = "";
        graph.refresh();
        check("no sink named: nothing is asked", runner("wpexec").running, false);

        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
