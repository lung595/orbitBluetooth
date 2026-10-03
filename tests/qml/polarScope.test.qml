import QtQuick

// Test of PolarScope: presses land on the right half circle, and the
// cloud's clock runs while dots are alive, then stops by itself (nothing
// runs at rest, value 6); hiding the scope stops it at once.
// Run with tests/qml/run.sh.
Item {
    id: h
    width: 360
    height: 200

    PolarScope {
        id: scope
        anchors.fill: parent
        deviceLevel: 0.6
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
    function at(r) {
        return Qt.point(scope.cx, scope.cy - r);
    }

    Component.onCompleted: {
        check("top of the outer half is the device", scope.pointer.partAt(at(scope.outer)), "device");
        check("top of the inner half is this PC", scope.pointer.partAt(at(scope.inner)), "pc");
        check("between them: nothing", scope.pointer.partAt(at((scope.outer + scope.inner) / 2)), "");
        check("the top is half way", scope.pointer.valueAt("pc", at(scope.inner)), 0.5);
        check("at rest the clock is stopped", scope.animating, false);

        scope.simulate({
            l: [0.8, 0.5],
            r: [0.6, 0.7]
        }, 0.2);
        scope.wake();
        check("living dots start the clock", scope.animating, true);
        settle.start();
    }
    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            check("the clock stops by itself once the dots fade", scope.animating, false);
            scope.simulate({
                l: [0.8],
                r: [0.8]
            }, 0.2);
            scope.wake();
            scope.live = false;
            check("hidden: the clock stops at once", scope.animating, false);
            print(h.failures ? h.failures + " failure(s)" : "all passed");
            Qt.exit(h.failures ? 1 : 0);
        }
    }
}
