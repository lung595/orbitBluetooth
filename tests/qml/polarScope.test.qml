import QtQuick
import "components/volume"

// Test of PolarScope and ScopeModel: presses land on the right half
// circle, and a wheel notch on an icon scrolls its own level; a level step eases on a clock that stops alone; the shared
// picture moves on its feed's frames and its fade stops by itself, for
// every style (nothing runs at rest, value 6); a feed turned off clears it;
// a late frame is not taken for silence, and silence paints nothing.
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
    // The last level a wheel notch asked for, and how many were asked
    property var lastMove: null
    property int moves: 0
    Connections {
        target: scope
        function onMoved(part, level) {
            h.lastMove = [part, level];
            h.moves++;
        }
    }
    // One wheel notch at the foot of a half circle (where its icon sits)
    function notchAtFoot(radius) {
        const p = scope.pointer;
        p.turn(p.wheelPartAt(Qt.point(scope.cx - radius, scope.cy + 14)), 120);
    }

    Component.onCompleted: {
        check("top of the outer half is the device", scope.pointer.partAt(at(scope.outer)), "device");
        check("top of the inner half is this PC", scope.pointer.partAt(at(scope.inner)), "pc");
        check("between them: nothing", scope.pointer.partAt(at((scope.outer + scope.inner) / 2)), "");
        check("the top is half way", scope.pointer.valueAt("pc", at(scope.inner)), 0.5);
        check("a notch on the outer arc's icon scrolls the device", (notchAtFoot(scope.outer), h.lastMove), ["device", 0.65]);
        check("a notch on this PC's icon scrolls this PC", (notchAtFoot(scope.inner), h.lastMove), ["pc", 0.45]);
        h.moves = 0;
        scope.pointer.turn("device", 60);
        scope.pointer.turn("pc", 60);
        check("half notches on two levels do not add up", h.moves, 0);
        check("at rest the clock is stopped", scope.animating, false);

        // A level step (once every item is ready) eases on the scope's
        // clock, which stops alone
        Qt.callLater(() => {
            scope.pcLevel = 0.7;
            check("a level step starts the clock", scope.animating, true);
            check("the shown level eases, it does not jump", scope._pc < 0.7, true);
        });

        // Frames from a feed move the shared picture; when they stop, the
        // light fades and its clock stops by itself
        feed.push({
            "l": [0.8, 0.5],
            "r": [0.6, 0.7]
        });
        check("a frame lights dots", model.alive > 0, true);
        check("the dots fade on their own clock", model.animating, true);
        settle.start();
    }
    // A made-up ScopeFeed
    Item {
        id: feed
        property var frame: null
        property bool active: true
        signal arrived
        function push(f) {
            frame = f;
            arrived();
        }
    }
    ScopeModel {
        id: model
        feed: feed
        gain: 0.5
    }
    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            check("the level clock stopped once settled", scope.animating, false);
            check("the level reached its value", scope._pc, 0.7);
            check("the fade stops by itself once the dots are gone", model.animating, false);
            check("nothing left alive", model.alive, 0);
            feed.push({
                "l": [0.8],
                "r": [0.8]
            });
            feed.active = false;
            check("feed off: the picture clears at once", [model.alive, model.animating], [0, false]);
            feed.active = true;
            h.nextStyle();
        }
    }

    // Rays and waves fall back like meters: their fade stops alone too
    property var styles: ["rays", "waves"]
    function nextStyle() {
        if (!styles.length) {
            model.fps = 20;
            h.pictures = 0;
            lateFeed.start();
            return;
        }
        model.style = styles.shift();
        feed.push({
            "l": [0.9, 0.6, 0.3],
            "r": [0.5, 0.7, 0.2]
        });
        check(model.style + ": sound starts the fade", model.animating, true);
        styleSettle.start();
    }
    Timer {
        id: styleSettle
        interval: 2500
        onTriggered: {
            check(model.style + ": the fade stops by itself", model.animating, false);
            h.nextStyle();
        }
    }

    // cava's frames come a little late (60 ms at 20 frames/s): each one
    // makes one picture, with no blank step of the fade before it
    property int pictures: 0
    Connections {
        target: model
        function onUpdated() {
            h.pictures++;
        }
    }
    Timer {
        id: lateFeed
        property int left: 10
        interval: 60
        repeat: true
        onTriggered: {
            feed.push({
                "l": [0.8],
                "r": [0.6]
            });
            if (--left > 0)
                return;
            stop();
            h.check("a late frame gets no blank step before it", h.pictures, 10);
            silenceSettle.start();
        }
    }
    // Silent frames on a blank picture: nothing to paint, nothing runs
    Timer {
        id: silenceSettle
        interval: 2500
        onTriggered: {
            h.pictures = 0;
            for (let i = 0; i < 3; i++)
                feed.push({
                    "l": [0],
                    "r": [0]
                });
            h.check("silence on a blank picture paints nothing", [h.pictures, model.animating], [0, false]);
            print(h.failures ? h.failures + " failure(s)" : "all passed");
            Qt.exit(h.failures ? 1 : 0);
        }
    }
}
