import QtQuick
import "Polar.js" as Polar

// The moons of the scope (PolarScope): the knobs at the end of each lit arc,
// to drag. A muted level shows a hollow moon in the muted ink; the one under
// the pointer, being dragged or just scrolled grows a little
Item {
    id: moons

    // The scope (PolarScope.qml): its geometry, colors, eased levels and
    // gesture state
    required property var scope

    anchors.fill: parent

    component Moon: Rectangle {
        property string part: ""
        property real radiusAt: 0
        property real deg: 180
        property color tint: "white"
        property bool hollow: false
        readonly property bool big: moons.scope.talking === part || moons.scope.dragging === part || moons.scope.pointer.hover === part
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

    Repeater {
        model: moons.scope.outputs.length
        Moon {
            required property int index
            readonly property var out: moons.scope.output(index)
            part: out.part
            radiusAt: moons.scope.outer
            deg: Polar.end(moons.scope.sliceOf(index), moons.scope.shownAt(index))
            tint: out.muted ? moons.scope.mutedColor : out.color
            hollow: out.muted
        }
    }
    Moon {
        part: "pc"
        radiusAt: moons.scope.inner
        deg: Polar.end(moons.scope.innerSlice, moons.scope.shownPc)
        tint: moons.scope.pcMuted ? moons.scope.mutedColor : moons.scope.pcColor
        hollow: moons.scope.pcMuted
    }
}
