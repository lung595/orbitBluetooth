import QtQuick
import "Polar.js" as Polar

// The two moons of the scope (PolarScope): the knobs at the end of each
// lit arc, to drag. A muted level shows a hollow moon in the muted ink; the
// one under the pointer, being dragged or just scrolled grows a little
Item {
    id: moons

    // The scope (PolarScope.qml): its geometry, colors, eased levels and
    // gesture state
    required property var scope

    anchors.fill: parent

    component Moon: Rectangle {
        property real radiusAt: 0
        property real deg: 180
        property color tint: "white"
        property bool hollow: false
        property bool big: false
        readonly property real knob: big ? 11 : 8
        width: knob
        height: knob
        radius: knob / 2
        x: moons.scope.cx + Math.cos(deg * Math.PI / 180) * radiusAt - knob / 2
        y: moons.scope.cy + Math.sin(deg * Math.PI / 180) * radiusAt - knob / 2
        color: hollow ? moons.scope.hollowColor : moons.scope.inkColor
        border.width: 1.5
        border.color: tint
    }

    Moon {
        visible: moons.scope.hasDevice
        radiusAt: moons.scope.outer
        deg: Polar.end("outer", moons.scope.shownDevice)
        tint: moons.scope.deviceMuted ? moons.scope.mutedColor : moons.scope.deviceColor
        hollow: moons.scope.deviceMuted
        big: moons.scope.talking === "device" || moons.scope.dragging === "device" || moons.scope.pointer.hover === "device"
    }
    Moon {
        radiusAt: moons.scope.inner
        deg: Polar.end("inner", moons.scope.shownPc)
        tint: moons.scope.pcMuted ? moons.scope.mutedColor : moons.scope.pcColor
        hollow: moons.scope.pcMuted
        big: moons.scope.talking === "pc" || moons.scope.dragging === "pc" || moons.scope.pointer.hover === "pc"
    }
}
