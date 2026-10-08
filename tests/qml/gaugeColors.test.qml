import QtQuick
import QtTest
import "components/centre"
import "components/centre/Gauge.js" as Gauge

// The gauge's colours along its arc (NAK-17): the conical gradient has to run
// from the start colour at the arc's start to the end colour at its end, one
// way and with no jump. Qt counts a conical gradient's angle the other way
// round from the rest of the gauge, so a wrong mapping still draws a
// gradient, only in the wrong place: the pure test cannot see it, a render
// can. The gauge is drawn off screen at level 1 with a red start and a blue
// end and its band is sampled. Run with tests/qml/run.sh.
Item {
    id: h
    width: 200
    height: 200

    LevelGauge {
        id: gauge
        radius: 70
        level: 1
        startColor: "#ff0000"
        endColor: "#0000ff"
    }
    // Only here for grabImage; left to run (`when` true) it would find no
    // test function, finish and quit the whole test before the steps
    TestCase {
        id: shot
        name: "gaugeColors"
        when: false
    }

    property int failures: 0
    function check(what, ok, got) {
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got)));
    }
    function run() {
        const image = shot.grabImage(gauge);
        const mid = gauge.mid;
        // The colour on the band at level v
        function sample(v) {
            const p = Gauge.pointAt(mid, mid, gauge.radius, v);
            const x = Math.round(p.x), y = Math.round(p.y);
            return [image.red(x, y), image.green(x, y), image.blue(x, y)];
        }
        const first = sample(0.02), middle = sample(0.5), last = sample(0.98);
        check("the start of the arc has the start colour", first[0] > 235 && first[2] < 20, first);
        check("the middle is a mix of the two", Math.abs(middle[0] - 127) < 30 && Math.abs(middle[2] - 127) < 30, middle);
        check("the end of the arc has the end colour", last[0] < 20 && last[2] > 235, last);
        // One way, with no jump between neighbours (a seam on the band would
        // show as a step of most of the range)
        let jump = 0, back = 0, previous = first;
        for (let i = 2; i <= 98; i++) {
            const c = sample(i / 100);
            jump = Math.max(jump, Math.abs(c[0] - previous[0]));
            back = Math.max(back, c[0] - previous[0]);
            previous = c;
        }
        check("no jump between neighbouring points (largest step " + jump + ")", jump < 25, jump);
        check("the red only fades along the arc (largest rise " + back + ")", back < 4, back);
    }

    // The window has to be up before the grab
    Timer {
        interval: 300
        running: true
        onTriggered: {
            h.run();
            print(h.failures ? h.failures + " failure(s)" : "all passed");
            Qt.exit(h.failures ? 1 : 0);
        }
    }
    // A step that throws must fail the test, not leave it waiting for ever
    Timer {
        interval: 20000
        running: true
        onTriggered: {
            print("FAIL timed out: a step threw");
            Qt.exit(1);
        }
    }
}
