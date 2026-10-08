import QtQuick
import QtTest
import "components/centre"
import "components/centre/Gauge.js" as Gauge

// The gauge under a pointer (NAK-17): press, drag, hover and release with real
// mouse events (QtTest) on the real CentreRing, off screen, so that nothing is
// tried on the live shell. A press lands where the pointer is, a drag follows
// it along the arc and holds at the ends across the gap, the gap itself is not
// the gauge's, hovering writes the level out, a release ends the drag and the
// speaker mutes without dragging to zero. The volume and the scene are
// stand-ins with only what the gauge reads. Run with tests/qml/run.sh.
Item {
    id: h
    width: 400
    height: 400

    QtObject {
        id: fake
        property real level: 0.4
        property bool ready: true
        property bool muted: false
        function set(value) {
            level = value;
        }
        function step(dir) {
            level += dir * 0.05;
        }
        function toggleMute() {
            muted = !muted;
        }
    }
    QtObject {
        id: night
        readonly property color primary: "#6aa7ff"
        readonly property color tertiary: "#c58cff"
        function ink(alpha) {
            return Qt.rgba(1, 1, 1, alpha);
        }
        function smoke(alpha) {
            return Qt.rgba(0.04, 0.045, 0.06, alpha);
        }
    }
    QtObject {
        id: stand
        readonly property var volume: fake
        readonly property var scene: ({
                "night": night,
                "coreSize": 75
            })
        readonly property var sizes: ({
                "ring": 60,
                "source": 40,
                "chipIcon": 17,
                "chip": 25
            })
        property var group: ({
                "x": 200,
                "y": 200,
                "scale": 1
            })
        readonly property real presence: 1
        // The source disc: its body follows its slot on a spring, so it is
        // not where the group is (a wired source has no body: the group's rule
        // puts it there)
        readonly property string source: "source"
        property bool wired: false
        property var disc: ({
                "px": 190,
                "py": 205,
                "diameter": 40,
                "baseScale": 1
            })
        function bodyOf(address) {
            return wired ? null : disc;
        }
        function spotOf(address) {
            return {
                "x": group.x,
                "y": group.y,
                "size": sizes.source * group.scale
            };
        }
    }
    CentreRing {
        id: ring
        centre: stand
        holdTime: 60
    }

    // Only here for its mouse events: left to run (`when` true) it would find
    // no test function, finish and quit the whole test before the steps
    TestCase {
        id: mouse
        name: "gaugePointer"
        when: false
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    function named(item, name) {
        for (const child of item.children) {
            if (child.objectName === name)
                return child;
            const found = named(child, name);
            if (found)
                return found;
        }
        return null;
    }
    // The ring's local point at level `v` on its band (r = the radius), or 12 px outside it
    function at(v, off) {
        return Gauge.pointAt(ring.width / 2, ring.height / 2, ring.radius + (off || 0), v);
    }
    function pressAt(v) {
        const p = at(v);
        mouse.mousePress(ring, p.x, p.y);
    }
    function moveTo(v) {
        const p = at(v);
        mouse.mouseMove(ring, p.x, p.y);
    }
    // The point straight below the middle, in the gap: nothing there is the gauge's
    function gap() {
        return {
            "x": ring.width / 2,
            "y": ring.height / 2 + ring.radius
        };
    }
    readonly property real tol: 0.02

    function run() {
        const tag = named(ring, "reading");
        check("at rest: nothing is written out", tag.visible, false);

        // Hover: the level is written out while the pointer is on the band, and only there
        moveTo(0.5);
        check("hovering the band writes the level out", tag.visible, true);
        mouse.mouseMove(ring, gap().x, gap().y);
        check("the gap is not the gauge: moving into it ends the hover", tag.visible, false);
        mouse.mouseMove(ring, ring.width / 2, ring.height / 2);
        check("the middle (the planet) is not the gauge either", tag.visible, false);

        // Press: it lands where the pointer is, whatever the level was
        fake.level = 0.4;
        pressAt(0.75);
        check("a press jumps to the place", Math.abs(fake.level - 0.75) < tol, true);
        check("held, the reading stays on", tag.visible, true);

        // Drag along the arc, both ways
        moveTo(0.9);
        check("a drag follows the pointer up", Math.abs(fake.level - 0.9) < tol, true);
        moveTo(0.2);
        check("and down", Math.abs(fake.level - 0.2) < tol, true);

        // Across the gap it holds the end it came from, no jump to the other end
        mouse.mouseMove(ring, gap().x, gap().y);
        check("dragged into the gap from the low end: held at 0", fake.level, 0);
        moveTo(0.95);
        mouse.mouseMove(ring, gap().x, gap().y);
        check("dragged into the gap from the high end: held at 1", fake.level, 1);

        // Release: the drag is over, a move changes nothing
        const p = at(0.3);
        mouse.mouseRelease(ring, p.x, p.y);
        const kept = fake.level;
        moveTo(0.6);
        check("after the release a move changes nothing", fake.level, kept);

        // A press in the gap is not the gauge's
        fake.level = 0.5;
        mouse.mousePress(ring, gap().x, gap().y);
        mouse.mouseRelease(ring, gap().x, gap().y);
        check("a press in the gap does nothing", fake.level, 0.5);

        // A press fresh from a drag starts over, from where it lands
        pressAt(0.1);
        mouse.mouseRelease(ring, at(0.1).x, at(0.1).y);
        check("a new press lands again", Math.abs(fake.level - 0.1) < tol, true);

        // The speaker mutes, and is not a drag to zero
        fake.level = 0.6;
        const chip = named(ring, "speaker");
        mouse.mouseClick(chip, chip.width / 2, chip.height / 2);
        check("the speaker mutes the group and leaves the level", [fake.muted, fake.level], [true, 0.6]);
        mouse.mouseClick(chip, chip.width / 2, chip.height / 2);
        check("and brings it back", fake.muted, false);
    }

    // The window has to be up before the events go in
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
