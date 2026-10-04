import QtQuick
import "components/volume"

// Test of PolarScope listening together (D254): the outer half circle is two
// quarters, one per output, and a press, a drag or a wheel notch lands on the
// right one; the shared inner half stays one; the second level eases on the
// same clock, which stops alone (nothing runs at rest, value 6).
// Run with tests/qml/run.sh.
Item {
    id: h
    width: 360
    height: 200

    PolarScope {
        id: scope
        anchors.fill: parent
        split: true
        deviceLevel: 0.6
        secondLevel: 0.3
        pcLevel: 0.4
        live: true
        motion: true
    }

    property int failures: 0
    function check(what, got, want) {
        const ok = JSON.stringify(got) === JSON.stringify(want);
        if (!ok)
            failures++;
        print((ok ? "ok   " : "FAIL ") + what + (ok ? "" : "  got " + JSON.stringify(got) + " want " + JSON.stringify(want)));
    }
    // A point on a circle of radius r around the center, deg as Polar.js counts
    function on(r, deg) {
        const a = deg * Math.PI / 180;
        return Qt.point(scope.cx + Math.cos(a) * r, scope.cy + Math.sin(a) * r);
    }
    property var lastMove: null
    Connections {
        target: scope
        function onMoved(part, level) {
            h.lastMove = [part, level];
        }
    }

    Component.onCompleted: {
        const p = scope.pointer;
        check("split gives the scope a device even with no own level", scope.hasDevice, true);
        check("the left quarter is the first output", p.partAt(on(scope.outer, 225)), "device");
        check("the right quarter is the second output", p.partAt(on(scope.outer, 315)), "second");
        check("the inner half is shared", p.partAt(on(scope.inner, 315)), "pc");
        check("a drag at the middle of the left quarter is half", p.valueAt("device", on(scope.outer, 225)), 0.5);
        check("a drag at the middle of the right quarter is half", p.valueAt("second", on(scope.outer, 315)), 0.5);
        check("each quarter is full at the top", [p.valueAt("device", on(scope.outer, 270)), p.valueAt("second", on(scope.outer, 270))], [1, 1]);
        check("each quarter is empty at its bottom corner", [p.valueAt("device", on(scope.outer, 180)), p.valueAt("second", on(scope.outer, 360))], [0, 0]);
        // A wheel notch at each foot scrolls its own output
        p.turn(p.wheelPartAt(Qt.point(scope.cx + scope.outer, scope.cy + 14)), 120);
        check("a notch at the right foot scrolls the second output", h.lastMove, ["second", 0.35]);
        p.turn(p.wheelPartAt(Qt.point(scope.cx - scope.outer, scope.cy + 14)), 120);
        check("a notch at the left foot scrolls the first output", h.lastMove, ["device", 0.65]);
        // Clicking the icon at each foot mutes its own output
        let muted = "";
        scope.muteClicked.connect(part => muted = part);
        p.pressed(Qt.point(scope.cx + scope.outer, scope.cy + 6 + scope.iconSize / 2));
        check("the right foot's icon mutes the second output", muted, "second");
        check("at rest the clock is stopped", scope.animating, false);

        Qt.callLater(() => {
            scope.secondLevel = 0.8;
            check("a second level step starts the clock", scope.animating, true);
            check("it eases, it does not jump", scope._second < 0.8, true);
            settle.start();
        });
    }
    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            check("the second level reached its value", scope._second, 0.8);
            check("the clock stopped once settled", scope.animating, false);
            scope.split = false;
            check("not split any more: the outer half is the device's alone", scope.pointer.partAt(h.on(scope.outer, 315)), "device");
            print(h.failures ? h.failures + " failure(s)" : "all passed");
            Qt.exit(h.failures ? 1 : 0);
        }
    }
}
