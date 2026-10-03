import QtQuick
import qs.Common
import qs.Widgets
import "Polar.js" as Polar

// Who is who and how loud, over the polar scope (PolarScope): an icon at
// the foot of each half circle, the percentage next to its moon while it
// moves, or beside the half circles when there is room (D264). Fills the
// scope, so every position is in the scope's own coordinates.
Item {
    // The scope (PolarScope.qml): its geometry, levels, colors and who talks
    required property var scope

    // Who is who: an icon at the foot of each half circle, where it starts
    DankIcon {
        visible: scope.hasDevice
        name: scope.deviceMuted ? "volume_off" : scope.deviceIcon
        size: scope.iconSize
        color: scope.deviceMuted ? scope.mutedColor : scope.deviceColor
        rotation: -scope.rotation
        x: scope.cx - scope.outer - width / 2
        y: scope.cy + 6
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
    Readout {
        radiusAt: scope.outer
        deg: Polar.end("outer", scope._dev)
        text: Math.round(Math.max(0, scope.deviceLevel) * 100) + "%"
        color: scope.deviceColor
        shown: scope.hasDevice && !scope.sideNumbers && (scope.numbers || scope.talking === "device" || scope.dragging === "device")
    }
    Readout {
        // Inside the inner arc, so it never meets the outer moon
        radiusAt: scope.inner
        gap: -26
        deg: Polar.end("inner", scope._pc)
        text: Math.round(scope.pcLevel * 100) + "%"
        color: scope.pcColor
        shown: !scope.sideNumbers && (scope.numbers || scope.talking === "pc" || scope.dragging === "pc")
    }

    // Beside the half circles: the device's level on the left, where its
    // arc starts, this PC's on the right
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
        visible: scope.sideNumbers && scope.hasDevice
        x: 6
        level: Math.max(0, scope.deviceLevel)
        muted: scope.deviceMuted
        tint: scope.deviceColor
        label: scope.deviceLabel
        lit: scope.talking === "device" || scope.dragging === "device"
    }
    SideNumber {
        visible: scope.sideNumbers
        x: scope.width - width - 6
        level: scope.pcLevel
        muted: scope.pcMuted
        tint: scope.pcColor
        label: scope.pcLabel
        lit: scope.talking === "pc" || scope.dragging === "pc"
    }
}
