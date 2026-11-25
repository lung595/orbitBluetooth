import QtQuick
import "components/volume"
import "components/volume/Polar.js" as Polar

// Test of PolarScope listening together (D254, D277): the outer half circle is
// cut into one arc per output, two to four, and a press, a drag, a wheel notch
// or an icon lands on the right one, whichever way it lights; the shared inner
// half stays one; levels ease on one clock that stops alone (nothing runs at
// rest, value 6), and a change of count never reads an arc that is gone.
// Run with tests/qml/run.sh.
Item {
    id: h
    width: 460
    height: 176

    function member(level, label) {
        return {
            "level": level,
            "muted": false,
            "icon": "speaker",
            "label": label
        };
    }
    PolarScope {
        id: scope
        anchors.fill: parent
        members: [h.member(0.6, "One"), h.member(0.3, "Two"), h.member(0.5, "Three")]
        memberColors: ["#ff0000", "#00ff00", "#0000ff", "#ffff00"]
        pcLevel: 0.4
        live: true
        motion: true
    }

    Tally {
        id: tally
    }
    // A point on a circle of radius r around the center, deg as Polar.js counts
    function on(r, deg) {
        const a = deg * Math.PI / 180;
        return Qt.point(scope.cx + Math.cos(a) * r, scope.cy + Math.sin(a) * r);
    }
    // The middle, the lit-from end and the lit end of arc i, in degrees
    function mid(i) {
        const s = scope.sliceOf(i);
        return (s.start + s.end) / 2;
    }
    function litFrom(i) {
        const s = scope.sliceOf(i);
        return s.reverse ? s.end : s.start;
    }
    function litTo(i) {
        const s = scope.sliceOf(i);
        return s.reverse ? s.start : s.end;
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
        tally.check("three outputs: three arcs, in the order they joined", scope.outputs.map(o => o.part), ["m0", "m1", "m2"]);
        tally.check("each arc takes its own color", scope.outputs.map(o => o.color.toString()), ["#ff0000", "#00ff00", "#0000ff"]);
        tally.check("the percentages go by their names, not by the sides", scope.sideNumbers, false);
        tally.check("each arc answers for its press", [0, 1, 2].map(i => p.partAt(on(scope.outer, mid(i)))), ["m0", "m1", "m2"]);
        tally.check("the inner half is shared", p.partAt(on(scope.inner, 300)), "pc");
        tally.check("an arc empty and full at its ends, lit from the foot or the middle toward the top", [0, 1, 2].map(i => [p.valueAt("m" + i, on(scope.outer, litFrom(i))), p.valueAt("m" + i, on(scope.outer, litTo(i)))]), [[0, 1], [0, 1], [0, 1]]);
        tally.check("half way along an arc is half", [0, 1, 2].map(i => p.valueAt("m" + i, on(scope.outer, mid(i)))), [0.5, 0.5, 0.5]);
        // A wheel notch at each foot scrolls the first and the last output
        p.turn(p.wheelPartAt(Qt.point(scope.cx + scope.outer, scope.cy + 14)), 120);
        tally.check("a notch at the right foot scrolls the last output", h.lastMove, ["m2", 0.55]);
        p.turn(p.wheelPartAt(Qt.point(scope.cx - scope.outer, scope.cy + 14)), 120);
        tally.check("a notch at the left foot scrolls the first output", h.lastMove, ["m0", 0.65]);
        p.turn(p.wheelPartAt(on(scope.outer, mid(1))), 120);
        tally.check("a notch on the middle arc scrolls it", h.lastMove, ["m1", 0.35]);
        // Each icon is where it was put and mutes its own output
        tally.check("each output's icon finds its output", [0, 1, 2].map(i => {
            const s = Polar.iconSpot(i, 3, scope.cx, scope.cy, scope.outer, scope.iconSize);
            return p.iconAt(Qt.point(s.x, s.y));
        }), ["m0", "m1", "m2"]);
        tally.check("this PC's icon is at the foot of the inner half", p.iconAt(Qt.point(scope.cx - scope.inner, scope.cy + 6 + scope.iconSize / 2)), "pc");
        tally.check("at rest the clock is stopped", scope.animating, false);

        // A level step on one output eases on the scope's clock, which stops
        Qt.callLater(() => {
            scope.members = [h.member(0.6, "One"), h.member(0.9, "Two"), h.member(0.5, "Three")];
            tally.check("a level step starts the clock", scope.animating, true);
            tally.check("it eases, it does not jump", scope.shownAt(1) < 0.9, true);
            settle.start();
        });
    }
    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            tally.check("the level reached its value", scope.shownAt(1), 0.9);
            tally.check("the clock stopped once settled", scope.animating, false);

            // A fourth output joins, then one leaves: arcs follow, new ones
            // start where they are (nothing eases from a stale index)
            scope.members = scope.members.concat([h.member(0.7, "Four")]);
            tally.check("four outputs: four arcs", scope.outputs.map(o => o.part), ["m0", "m1", "m2", "m3"]);
            tally.check("the new arc starts at its level", scope.shownAt(3), 0.7);
            tally.check("an arc that is not there answers for nothing", [scope.output(7).part, scope.sliceOf(7).end > 0], ["", true]);
            scope.members = scope.members.slice(0, 2);
            tally.check("two outputs: the D254 pair", scope.outputs.map(o => o.part), ["m0", "m1"]);
            tally.check("two outputs: the percentages go beside the half circles when asked", (scope.numbers = true, scope.sideNumbers), true);
            scope.numbers = false;
            // Over the limit, the arcs stop at four
            scope.members = [0, 1, 2, 3, 4, 5].map(i => h.member(0.5, "n" + i));
            tally.check("more than four outputs: only four arcs", scope.outputs.length, 4);
            // Back to a device alone, or nothing
            scope.members = [];
            scope.deviceLevel = 0.6;
            tally.check("no outputs together: the device's own arc", scope.outputs.map(o => o.part), ["device"]);
            tally.check("the device's own arc is the whole outer half", [scope.pointer.partAt(h.on(scope.outer, 200)), scope.pointer.partAt(h.on(scope.outer, 340))], ["device", "device"]);
            scope.deviceLevel = -1;
            tally.check("no output at all: no outer arc", [scope.hasDevice, scope.pointer.partAt(h.on(scope.outer, 270))], [false, ""]);
            tally.finish();
        }
    }
}
