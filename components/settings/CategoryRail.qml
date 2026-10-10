import QtQuick
import QtQuick.Shapes
import qs.Common

// The categories of the settings page, left of the content: bodies on one
// dashed orbit like a star chart. 160 px wide, 48 px with icons only when
// the page is narrow. Static by construction: no timer, no animation.
Item {
    id: rail

    required property var view

    readonly property real bodyX: view.compact ? 24 : 28
    readonly property int rowHeight: 44

    width: view.compact ? 48 : 160
    height: view.categories.length * rowHeight
    Accessible.role: Accessible.PageTabList

    // The trajectory runs from the first body's centre to the last one's;
    // 3 px dashes 3 px apart (a dash pattern counts in stroke widths)
    Shape {
        anchors.fill: parent
        ShapePath {
            fillColor: "transparent"
            strokeColor: Theme.withAlpha(Theme.surfaceText, 0.16)
            strokeWidth: 2
            strokeStyle: ShapePath.DashLine
            dashPattern: [1.5, 1.5]
            startX: rail.bodyX
            startY: rail.rowHeight / 2
            PathLine {
                x: rail.bodyX
                y: rail.height - rail.rowHeight / 2
            }
        }
    }

    Column {
        width: parent.width
        Repeater {
            model: rail.view.categories
            RailEntry {
                width: rail.width
                view: rail.view
                bodyX: rail.bodyX
            }
        }
    }
}
