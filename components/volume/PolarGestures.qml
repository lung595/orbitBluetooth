import QtQuick
import "Polar.js" as Polar

// The gestures of the scope (PolarScope): drag along an arc, scroll over
// it, or click the icon at the foot of a half circle to mute it. It only
// asks, through the scope's signals; the scope owns the levels
MouseArea {
    id: pointer

    // The scope (PolarScope.qml): its geometry and signals
    required property var scope

    anchors.fill: parent
    enabled: scope.interactive
    hoverEnabled: true
    preventStealing: true
    // The part under the pointer: "device", "second", "pc" or ""
    property string hover: ""
    cursorShape: hover || scope.dragging ? Qt.PointingHandCursor : Qt.ArrowCursor

    // The arc each part is dragged along (Polar.arc): the outer half, or its
    // two quarters when two outputs listen together
    function _arcOf(part) {
        return part === "pc" ? "inner" : part === "second" ? "d2" : scope.split ? "d1" : "outer";
    }
    function partAt(m) {
        const z = Polar.zone(m.x - scope.cx, m.y - scope.cy, scope.outer, scope.inner, Math.max(12, scope.stroke * 3), scope.split);
        return z === "inner" ? "pc" : z === "d2" ? "second" : z && scope.hasDevice ? "device" : "";
    }
    function valueAt(part, m) {
        return Polar.valueAt(_arcOf(part), m.x - scope.cx, m.y - scope.cy);
    }
    // The icons at the feet of the half circles mute or unmute their level
    function iconAt(m) {
        const near = (x, y) => Math.abs(m.x - x) <= scope.iconSize && Math.abs(m.y - y) <= scope.iconSize;
        const footY = scope.cy + 6 + scope.iconSize / 2;
        if (scope.hasDevice && near(scope.cx - scope.outer, footY))
            return "device";
        if (scope.split && near(scope.cx + scope.outer, footY))
            return "second";
        return near(scope.cx - scope.inner, footY) ? "pc" : "";
    }

    onPositionChanged: m => {
        hover = partAt(m);
        if (scope.dragging)
            scope.moved(scope.dragging, valueAt(scope.dragging, m));
    }
    onExited: hover = ""
    onPressed: m => {
        const part = partAt(m);
        if (!part) {
            const icon = iconAt(m);
            if (icon)
                scope.muteClicked(icon);
            else
                m.accepted = false;
            return;
        }
        scope.dragging = part;
        scope.talk(part);
        scope.moved(part, valueAt(part, m));
    }
    onReleased: {
        if (scope.dragging)
            scope.talk(scope.dragging);
        scope.dragging = "";
    }
    onCanceled: scope.dragging = ""

    // The level a wheel notch at m changes: the side under the pointer
    // (an arc, its icon or its number), never a dead spot
    function wheelPartAt(m) {
        return Polar.wheelPart(m.x - scope.cx, m.y - scope.cy, scope.outer, scope.inner, scope.sideNumbers, scope.hasDevice, scope.split);
    }

    // Scroll: 5 % steps, or the caller's own steps (smartWheel). A notch
    // left over from the other level does not count toward this one
    property real acc: 0
    property string turning: ""
    onWheel: w => turn(wheelPartAt(w), w.angleDelta.y)
    function turn(part, delta) {
        if (part !== turning) {
            turning = part;
            acc = 0;
        }
        acc += delta;
        const steps = Math.trunc(acc / 120);
        if (steps === 0)
            return;
        acc -= steps * 120;
        scope.talk(part);
        if (scope.smartWheel) {
            for (let k = 0; k < Math.abs(steps); k++)
                scope.stepped(part, steps > 0 ? 1 : -1);
            return;
        }
        const now = part === "device" ? scope.deviceLevel : part === "second" ? scope.secondLevel : scope.pcLevel;
        scope.moved(part, Polar.clamp01(Math.round(now * 20 + steps) / 20));
    }
}
