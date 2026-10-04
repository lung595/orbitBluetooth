import QtQuick
import "Polar.js" as Polar

// The moons of the scope (PolarScope), two (three listening together): the knobs at the end of each
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
        deg: Polar.end(moons.scope.split ? "d1" : "outer", moons.scope.shownDevice)
        tint: moons.scope.deviceMuted ? moons.scope.mutedColor : moons.scope.deviceColor
        hollow: moons.scope.deviceMuted
        big: moons.scope.talking === "device" || moons.scope.dragging === "device" || moons.scope.pointer.hover === "device"
    }
    // Listening together: the second output's moon, on the right quarter
    Moon {
        visible: moons.scope.split
        radiusAt: moons.scope.outer
        deg: Polar.end("d2", moons.scope.shownSecond)
        tint: moons.scope.secondMuted ? moons.scope.mutedColor : moons.scope.secondColor
        hollow: moons.scope.secondMuted
        big: moons.scope.talking === "second" || moons.scope.dragging === "second" || moons.scope.pointer.hover === "second"
    }
    Moon {
        radiusAt: moons.scope.inner
        deg: Polar.end("inner", moons.scope.shownPc)
        tint: moons.scope.pcMuted ? moons.scope.mutedColor : moons.scope.pcColor
        hollow: moons.scope.pcMuted
        big: moons.scope.talking === "pc" || moons.scope.dragging === "pc" || moons.scope.pointer.hover === "pc"
    }
}
