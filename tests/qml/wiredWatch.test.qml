import QtQuick
import "components/together"

// Test of WiredWatch: nothing runs until a view needs the list (value 6); the
// listing becomes the plugged wired outputs; the list is dropped as soon as
// nobody needs it; a failed command gives nothing; an identical listing does
// not replace the list. The command is fixed, no user data reaches it
// (value 11). Run with tests/qml/run.sh.
Item {
    id: h

    WiredWatch {
        id: watch
    }

    // What `pactl --format=json list sinks` says, cut down to what is read
    // (made-up devices: a USB interface, a jack with nothing plugged, a
    // Bluetooth output that is not wired)
    readonly property string listing: JSON.stringify([
        {
            "name": "alsa_output.usb-Maker_Interface-00.analog-stereo",
            "description": "Interface Stereo",
            "active_port": "analog-output",
            "ports": [
                {
                    "name": "analog-output",
                    "availability": "availability unknown"
                }
            ],
            "properties": {
                "device.bus": "usb"
            }
        },
        {
            "name": "alsa_output.pci-0000_00_1f.3.analog-stereo",
            "description": "Built-in Audio",
            "active_port": "analog-output-headphones",
            "ports": [
                {
                    "name": "analog-output-headphones",
                    "availability": "not available"
                }
            ],
            "properties": {
                "device.bus": "pci"
            }
        },
        {
            "name": "bluez_output.00_11_22_33_44_55.1",
            "description": "Headset",
            "properties": {}
        }
    ])

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }

    // The command runner inside WiredWatch: the only child that has a command
    function runner() {
        for (let i = 0; i < watch.data.length; i++)
            if (watch.data[i].command !== undefined)
                return watch.data[i];
        return null;
    }
    // The command ends with this output and exit code
    function finish(code, text) {
        const run = runner();
        run.stdout.text = text;
        run.running = false;
        run.exited(code);
    }
    function sinks() {
        return watch.outputs.map(o => o.sink);
    }

    Component.onCompleted: {
        check("a runner exists", runner() !== null, true);
        check("nobody needs the list: nothing runs", runner().running, false);
        watch.refresh();
        check("asking while nobody needs it runs nothing", runner().running, false);

        watch.active = true;
        check("needed: the listing is asked for", runner().running, true);
        check("the command is fixed", runner().command, ["pactl", "--format=json", "list", "sinks"]);
        check("while it is read, the list is not ready", watch.ready, false);
        finish(0, listing);
        check("only what is plugged in and wired is listed", sinks(), ["alsa_output.usb-Maker_Interface-00.analog-stereo"]);
        check("read: the list is ready", watch.ready, true);

        const first = watch.outputs;
        watch.refresh();
        finish(0, listing);
        check("the same listing again keeps the same list", watch.outputs === first, true);

        watch.refresh();
        finish(0, "[]");
        check("an output unplugged leaves the list", sinks(), []);

        watch.active = false;
        check("nobody needs it any more: the list is dropped", watch.outputs, []);
        check("it is not ready any more, and nothing runs", [watch.ready, runner().running], [false, false]);

        watch.active = true;
        finish(1, listing);
        check("a failed command gives nothing, and it was read", [watch.outputs, watch.ready], [[], true]);

        print(failures ? failures + " failure(s)" : "all passed");
        Qt.exit(failures ? 1 : 0);
    }
}
