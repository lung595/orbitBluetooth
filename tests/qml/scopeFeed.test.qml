import QtQuick
import Quickshell.Io
import "components/volume"

// Test of ScopeFeed (NAK-210): the scope never waits for cava. While the
// scope shows, PipeWire's peak meter feeds the cloud at once; cava starts
// when nothing holds it back (a burst of volume keys does, D272), and its
// first frame takes over without a gap. Nothing runs when the scope is
// hidden (value 6). Run with tests/qml/run.sh.
Item {
    id: h

    ScopeFeed {
        id: feed
        node: ({
                "name": "bluez_output.02_00_00_00_10_06.1"
            })
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // The feed's peak meter (the only child with `peaks`) and its cava
    function findMeter() {
        for (let i = 0; i < feed.data.length; i++)
            if ("peaks" in feed.data[i])
                return feed.data[i];
        return null;
    }
    function cavaLine(v) {
        return new Array(32).fill(v).join(";") + ";";
    }

    // After every component has completed: the stand-in lists a process then
    Timer {
        interval: 1
        running: true
        onTriggered: h.run()
    }
    function run() {
        const meter = h.findMeter();
        const cava = ProcessLog.live[0];
        let arrivals = 0;
        feed.arrived.connect(() => arrivals++);

        check("hidden: no cava, no peak meter", [cava.running, meter.enabled], [false, false]);

        // A burst of volume keys: shown at once, cava held back
        feed.steady = false;
        feed.active = true;
        check("shown in a burst: the peak meter runs, cava waits", [cava.running, meter.enabled], [false, true]);
        meter.peaks = [0.5, 0.25];
        check("the peak meter draws the cloud at once", [arrivals, feed.frame.l, feed.frame.r], [1, [0.5], [0.25]]);

        // The keys stop: cava starts, the meter keeps going until it speaks
        feed.steady = true;
        check("the burst is over: cava starts, the meter still draws", [cava.running, meter.enabled], [true, true]);
        meter.peaks = [0.6, 0.3];
        check("until the first frame the meter still moves the cloud", feed.frame.l, [0.6]);
        cava.stdout.read(cavaLine(40));
        check("cava's first frame replaces it: 16 bands a side", [feed.frame.l.length, feed.frame.r.length], [16, 16]);
        check("then the meter stops", meter.enabled, false);
        meter.peaks = [0.9, 0.9];
        check("a late meter reading never overwrites cava", feed.frame.l.length, 16);

        // Keys again while cava runs: it is left alone
        feed.steady = false;
        check("a new burst does not stop a running cava", [cava.running, meter.enabled], [true, false]);

        // Hidden: everything stops
        feed.active = false;
        check("hidden again: nothing runs, no frame kept", [cava.running, meter.enabled, feed.frame], [false, false, null]);

        // Shown again during a burst: cava does not start from the old permission
        feed.active = true;
        check("shown again in a burst: the meter, not cava", [cava.running, meter.enabled], [false, true]);
        feed.steady = true;
        check("then cava", cava.running, true);

        // cava missing (exit 127): the meter stays, for good
        cava.running = false;
        cava.exited(127);
        check("without cava the meter goes on", [feed._noCava, meter.enabled], [true, true]);
        meter.peaks = [0.7, 0.7];
        check("and draws", feed.frame.l, [0.7]);

        print(h.failures ? h.failures + " failure(s)" : "all passed");
        Qt.exit(h.failures ? 1 : 0);
    }
}
