import QtQuick
import qs.Widgets
import "Polar.js" as Polar

// With three or four outputs listening together, who is who: each arc's name
// and level, written outside it at a place of its own (Polar.legendSpot) so
// two never meet, whatever the levels; icons alone do not tell two speakers
// apart. All of them while the numbers stay on, else only the one that
// moves. Fills the scope, in its own coordinates, like PolarReadouts.
Item {
    required property var scope

    Repeater {
        model: scope.outputs.length > 2 ? scope.outputs.length : 0
        Row {
            id: label
            required property int index
            readonly property var out: scope.output(index)
            readonly property var spot: Polar.legendSpot(index, scope.outputs.length, scope.cx, scope.cy, scope.outer, 14)
            // The room between the anchor and the edge it leans toward, so a
            // long name is cut short instead of running off the sheet
            readonly property real room: Math.min(scope.outer * 1.3, spot.align === "right" ? spot.x : spot.align === "left" ? scope.width - spot.x : 2 * Math.min(spot.x, scope.width - spot.x))
            readonly property real wide: Math.min(room, name.implicitWidth + spacing + level.implicitWidth)
            spacing: 4
            visible: scope.numbers || scope.talking === out.part || scope.dragging === out.part
            rotation: -scope.rotation
            x: Math.max(0, Math.min(scope.width - width, spot.align === "right" ? spot.x - width : spot.align === "left" ? spot.x : spot.x - width / 2))
            y: Math.max(0, spot.y - height / 2)

            // The name gives way, the level never does
            StyledText {
                id: name
                text: label.out.label
                width: Math.min(implicitWidth, label.room - label.spacing - level.implicitWidth)
                wrapMode: Text.NoWrap
                font.pixelSize: Math.max(11, Math.round(scope.outer * 0.1))
                font.weight: Font.DemiBold
                color: label.out.color
            }
            StyledText {
                id: level
                text: Math.round(label.out.level * 100) + "%"
                wrapMode: Text.NoWrap
                font.pixelSize: name.font.pixelSize
                font.weight: Font.DemiBold
                font.features: {
                    "tnum": 1
                }
                color: label.out.color
            }
        }
    }
}
