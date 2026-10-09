import QtQuick
import QtTest
import "components/centre"
import "components/device"

// The long press (NAK-10, D368): a left press held 500 ms does what a right click
// does, on a body and on a wired member; a drag past the threshold or an early
// release is not a hold; the release of a long press is not a click; the Timer
// runs only during the press. Real mouse events (QtTest) on the real pointers,
// off screen, with a stand-in scene that only counts what is asked of it. The
// ghost group (the third pointer) is tested in ghostGroup.test.qml. Run with tests/qml/run.sh.
Item {
    id: h
    width: 300
    height: 300

    // What the pointers ask of the scene
    Item {
        id: scene
        property bool cardOpen: false
        property var night: ({
                "primary": "#88aaff"
            })
        property var world: world
        property var log: []
        function openMenu(b, point) {
            log.push("menu");
        }
        function focusOn(b) {
            log.push("focus");
        }
        function beginDrag(b, p) {
            log.push("drag");
            b.dragging = true;
        }
        function updateDrag(p) {
        }
        function endDrag() {
            log.push("drop");
            body.dragging = false;
        }
        function wake() {
        }
        Item {
            id: world
        }
        Item {
            id: host
            anchors.fill: parent
            BodyPointer {
                id: bodyPointer
                body: body
            }
        }
    }
    QtObject {
        id: body
        property var scene: scene
        property bool leaving: false
        property bool swallowing: false
        property bool dragging: false
        property real diameter: 80
        property real baseScale: 1
    }

    TestCase {
        id: mouse
        name: "longPress"
        when: false
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // What happened since the last call
    function took() {
        const l = scene.log;
        scene.log = [];
        return l;
    }
    function ring(p) {
        return p.children.find(c => "fired" in c);
    }

    function run() {
        const p = bodyPointer;
        const r = ring(p);
        const c = p.width / 2;
        check("at rest: no Timer, no ring", [r.active, r.elapsed], [false, 0]);

        // Held 500 ms: the menu opens once, the ring is gone, the release is no click
        mouse.mousePress(p, c, c);
        check("pressed: the hold runs", r.active, true);
        mouse.wait(250);
        check("half way: no menu yet, the ring is drawn", [took(), r.elapsed > 120], [[], true]);
        mouse.wait(450);
        check("held 500 ms: the menu opened, once, and the Timer stopped", [took(), r.active, r.fired], [["menu"], false, true]);
        mouse.mouseRelease(p, c, c);
        check("the release after a long press is no click", [took(), r.fired], [[], false]);

        // A plain click: focus, never a menu
        mouse.mouseClick(p, c, c);
        check("a plain click only focuses", [took(), r.active], [["focus"], false]);

        // Released early at 300 ms: nothing is held any more
        mouse.mousePress(p, c, c);
        mouse.wait(300);
        mouse.mouseRelease(p, c, c);
        mouse.wait(400);
        check("released before 500 ms: no menu, even later", took().indexOf("menu"), -1);

        // A drag past 5 px cancels the hold, and carries the device
        mouse.mousePress(p, c, c);
        mouse.mouseMove(p, c + 12, c);
        check("moved past the threshold: the hold is cancelled", [r.active, took()], [false, ["drag"]]);
        mouse.wait(600);
        check("and the menu never opens while it is carried", took(), []);
        mouse.mouseRelease(p, c + 12, c);
        check("the drop ends the drag", took(), ["drop"]);

        // A wobble inside the threshold keeps the hold
        mouse.mousePress(p, c, c);
        mouse.mouseMove(p, c + 2, c + 2);
        mouse.wait(600);
        check("a small wobble still holds", took(), ["menu"]);
        mouse.mouseRelease(p, c + 2, c + 2);
        took();

        // Right click is unchanged and starts no hold
        mouse.mousePress(p, c, c, Qt.RightButton);
        check("right click: the menu at once, no hold", [took(), r.active], [["menu"], false]);
        mouse.mouseRelease(p, c, c, Qt.RightButton);

        // A card opened in the middle of a press ends it
        mouse.mousePress(p, c, c);
        scene.cardOpen = true;
        mouse.wait(600);
        check("a card opened during the press: no menu", [took(), r.active], [[], false]);
        scene.cardOpen = false;
    }

    Timer {
        interval: 300
        running: true
        onTriggered: {
            h.run();
            print(h.failures ? h.failures + " failure(s)" : "all passed");
            Qt.exit(h.failures ? 1 : 0);
        }
    }
    Timer {
        interval: 30000
        running: true
        onTriggered: {
            print("FAIL timed out: a step threw");
            Qt.exit(1);
        }
    }
}
