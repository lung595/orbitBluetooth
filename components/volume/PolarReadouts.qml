import QtQuick
import qs.Common
import qs.Widgets
import "Polar.js" as Polar

// Who is who and how loud, over the polar scope (PolarScope): an icon for
// each half circle, the percentage next to its moon while it moves, or
// beside the half circles when there is room (D264). Fills the
// scope, so every position is in the scope's own coordinates.
Item {
    id: readouts

    // The scope (PolarScope.qml): its geometry, levels, colors and who talks
    required property var scope

    // Who is who: an icon for each outer arc, at the foot of the half circle
    // for the first and the last (where they start), inside the arc by the
    // end it lights from for the others (Polar.iconSpot); this PC's at the
    // foot of the inner half
    Repeater {
        model: scope.outputs.length
        DankIcon {
            required property int index
            readonly property var out: scope.output(index)
            readonly property var spot: Polar.iconSpot(index, scope.outputs.length, scope.cx, scope.cy, scope.outer, scope.iconSize)
            name: out.muted ? "volume_off" : out.icon
            size: scope.iconSize
            color: out.muted ? scope.mutedColor : out.color
            rotation: -scope.rotation
            x: spot.x - width / 2
            y: spot.y - height / 2
        }
    }
    DankIcon {
        name: scope.pcMuted ? "volume_off" : scope.pcIcon
        size: scope.iconSize
        color: scope.pcMuted ? scope.mutedColor : scope.pcColor
        rotation: -scope.rotation
        x: scope.cx - scope.inner - width / 2
        y: scope.cy + 6
    }

    // The number, next to the moon that moves, only while it moves
    component Readout: StyledText {
        property real radiusAt: 0
        property real deg: 180
        property bool shown: false
        // Off the moon along its radius (negative: toward the center)
        property real gap: 24
        // No room above the outer moon (near the top edge): just inside it
        readonly property real _out: scope.cy + Math.sin(deg * Math.PI / 180) * (radiusAt + gap) - height / 2 >= 0 ? gap : -gap - 6
        readonly property real px: scope.cx + Math.cos(deg * Math.PI / 180) * (radiusAt + _out)
        readonly property real py: scope.cy + Math.sin(deg * Math.PI / 180) * (radiusAt + _out)
        x: Math.max(0, Math.min(scope.width - width, px - width / 2))
        y: Math.max(0, py - height / 2)
        rotation: -scope.rotation
        font.pixelSize: Math.max(11, Math.round(scope.outer * 0.1))
        font.weight: Font.DemiBold
        visible: shown
    }
    // The moon's number for one or two outputs; with more, PolarLegend names
    // them where they cannot meet
    Repeater {
        model: scope.outputs.length <= 2 ? scope.outputs.length : 0
        Readout {
            required property int index
            readonly property var out: scope.output(index)
            radiusAt: scope.outer
            deg: Polar.end(scope.sliceOf(index), scope.shownAt(index))
            text: Math.round(out.level * 100) + "%"
            color: out.color
            shown: !scope.sideNumbers && (scope.numbers || scope.talking === out.part || scope.dragging === out.part)
        }
    }
    PolarLegend {
        scope: readouts.scope
    }
    Readout {
        // Inside the inner arc, so it never meets the outer moon
        radiusAt: scope.inner
        gap: -26
        deg: Polar.end(scope.innerSlice, scope.shownPc)
        text: Math.round(scope.pcLevel * 100) + "%"
        color: scope.pcColor
        // Beside the half circles, the sides belong to the outputs, or to
        // this PC when there is a single one
        shown: (!scope.sideNumbers || scope.outputs.length > 1) && (scope.numbers || scope.talking === "pc" || scope.dragging === "pc")
    }

    // Beside the half circles: the first output's level on the left, where
    // its arc starts, on the right the second's, or this PC's with a single one
    component SideNumber: Column {
        property real level: 0
        property bool muted: false
        property color tint: "white"
        property string label: ""
        property bool lit: false
        readonly property real size: Math.max(18, Math.min(30, scope.outer * 0.22))
        y: scope.cy - scope.outer * 0.62 - height / 2
        width: scope.sideRoom
        spacing: 1
        rotation: -scope.rotation
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            StyledText {
                text: parent.parent.muted ? "Muted" : Math.round(parent.parent.level * 100)
                font.pixelSize: parent.parent.muted ? parent.parent.size * 0.6 : parent.parent.size
                font.weight: Font.DemiBold
                font.features: {
                    "tnum": 1
                }
                color: parent.parent.muted ? scope.mutedColor : parent.parent.tint
                anchors.baseline: unit.baseline
            }
            StyledText {
                id: unit
                visible: !parent.parent.muted
                text: "%"
                font.pixelSize: parent.parent.size * 0.5
                font.weight: Font.Medium
                color: Theme.withAlpha(parent.parent.tint, 0.7)
            }
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.label
            font.pixelSize: Math.max(10, Math.round(parent.size * 0.4))
            color: parent.lit ? parent.tint : scope.mutedColor
            width: Math.min(implicitWidth, scope.sideRoom)
            elide: Text.ElideRight
        }
    }
    SideNumber {
        readonly property var out: scope.output(0)
        visible: scope.sideNumbers && scope.hasDevice
        x: 6
        level: out.level
        muted: out.muted
        tint: out.color
        label: out.label
        lit: scope.talking === out.part || scope.dragging === out.part
    }
    SideNumber {
        // The second output's, or this PC's when there is a single one
        readonly property bool second: scope.outputs.length > 1
        readonly property var out: scope.output(1)
        readonly property string part: second ? out.part : "pc"
        visible: scope.sideNumbers
        x: scope.width - width - 6
        level: second ? out.level : scope.pcLevel
        muted: second ? out.muted : scope.pcMuted
        tint: second ? out.color : scope.pcColor
        label: second ? out.label : scope.pcLabel
        lit: scope.talking === part || scope.dragging === part
    }
}
