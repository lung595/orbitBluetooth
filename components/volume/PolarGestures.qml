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
    // The part under the pointer: "device", "pc" or ""
    property string hover: ""
    cursorShape: hover || scope.dragging ? Qt.PointingHandCursor : Qt.ArrowCursor

    function partAt(m) {
        const z = Polar.zone(m.x - scope.cx, m.y - scope.cy, scope.outer, scope.inner, Math.max(12, scope.stroke * 3), false);
        return z === "outer" ? (scope.hasDevice ? "device" : "") : z === "inner" ? "pc" : "";
    }
    function valueAt(part, m) {
        return Polar.valueAt(part === "device" ? "outer" : "inner", m.x - scope.cx, m.y - scope.cy);
    }
    // The icons at the feet of the half circles mute or unmute their level
    function iconAt(m) {
        const near = (x, y) => Math.abs(m.x - x) <= scope.iconSize && Math.abs(m.y - y) <= scope.iconSize;
        const footY = scope.cy + 6 + scope.iconSize / 2;
        if (scope.hasDevice && near(scope.cx - scope.outer, footY))
            return "device";
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

    // Scroll over an arc: 5 % steps, or the caller's own steps (smartWheel)
    property real acc: 0
    onWheel: w => {
        const part = hover || (scope.hasDevice ? "device" : "pc");
        acc += w.angleDelta.y;
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
        const now = part === "device" ? scope.deviceLevel : scope.pcLevel;
        scope.moved(part, Polar.clamp01(Math.round(now * 20 + steps) / 20));
    }
}
