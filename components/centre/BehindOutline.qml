import QtQuick
import QtQuick.Shapes

// What is left of a copy of the group while it is behind the source (D349): its
// disc has gone, and this dashed outline says it is still there, so the source
// it is drawn over stays readable and the copy still reads as a device. A circle
// for a Bluetooth device, a rounded square for a wired output (`corner` is the
// share of its side). Laid out once at the body's size and only faded by
// `solid` (Centre.solidity): nothing is painted or animated again, and it is not
// even drawn while the copy is whole.
Shape {
    id: outline

    // How whole the copy is, 0..1: the outline shows as it falls to 0
    required property real solid
    required property color ink
    // The corner's share of the side: 0.5 is a circle
    property real corner: 0.5
    // The dashes count in strokes: 2 of them dash, 2 gap
    readonly property real weight: 1.5

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    opacity: 1 - solid
    visible: opacity > 0.01

    ShapePath {
        strokeColor: outline.ink
        strokeWidth: outline.weight
        strokeStyle: ShapePath.DashLine
        dashPattern: [2, 2]
        fillColor: "transparent"
        PathRectangle {
            x: outline.weight / 2
            y: outline.weight / 2
            width: outline.width - outline.weight
            height: outline.height - outline.weight
            radius: width * outline.corner
        }
    }
}
