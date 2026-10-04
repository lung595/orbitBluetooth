import QtQuick
import "components/volume"

// Test of AudioFacts: nothing runs until a view is on screen and a sink is
// named (value 6); a listing becomes the facts of its sinks; the listing is
// dropped as soon as nobody looks; a failed command gives nothing. The
// command is fixed, no user data reaches it (value 11).
// Run with tests/qml/run.sh.
Item {
    id: h

    AudioFacts {
        id: facts
        sink: "alsa_output.usb-X.HiFi__Line1__sink"
    }

    // What `pactl --format=json list sinks` says, cut down to what is read
    readonly property string listing: JSON.stringify([
        {
            "name": "alsa_output.usb-X.HiFi__Line1__sink",
            "sample_specification": "s32le 2ch 192000Hz",
            "properties": {
                "device.bus": "usb",
                "device.api": "alsa",
                "api.alsa.path": "hw:Gen"
            }
        },
        {
            "name": "alsa_output.pci-0000_01_00.1.hdmi-stereo",
            "sample_specification": "s32le 2ch 48000Hz",
            "properties": {
                "device.bus": "pci",
                "device.api": "alsa",
                "api.alsa.path": "hdmi:0"
            }
        }
    ])

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // The command runner inside AudioFacts: the only child that has a command
    function runner() {
        for (let i = 0; i < facts.data.length; i++)
            if (facts.data[i].command !== undefined)
                return facts.data[i];
        return null;
    }
    // The command ends with this output and exit code
    function finish(code, text) {
        const run = runner();
        run.stdout.text = text;
        run.running = false;
        run.exited(code);
    }

    Component.onCompleted: {
        check("a runner exists", runner() !== null, true);
        check("nobody looks: nothing runs", runner().running, false);
        facts.refresh();
        check("asking while nobody looks runs nothing", runner().running, false);

        facts.active = true;
        check("looked at: the listing is asked for", runner().running, true);
        check("the command is fixed", runner().command, ["pactl", "--format=json", "list", "sinks"]);
        finish(0, listing);
        check("the output's facts arrive", [facts.facts.connection, facts.facts.rate, facts.facts.bits], ["USB", 192000, 32]);
        check("no PC filter, no PC facts", facts.pcFacts, null);

        facts.pcSink = "alsa_output.pci-0000_01_00.1.hdmi-stereo";
        check("a new sink to describe asks again", runner().running, true);
        finish(0, listing);
        check("the filter's facts arrive too", facts.pcFacts.connection, "HDMI");

        facts.active = false;
        check("nobody looks any more: the listing is dropped", [facts.facts, facts.pcFacts], [null, null]);
        check("and nothing runs", runner().running, false);

        facts.active = true;
        finish(1, "garbage");
        check("a failed command gives nothing", [facts.facts, facts.pcFacts], [null, null]);

        facts.sink = "";
        facts.refresh();
        check("no sink named: nothing is asked", runner().running, false);

        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
