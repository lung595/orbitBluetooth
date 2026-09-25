import QtQuick
import QtQuick.Shapes
import "Glyphs.js" as Glyphs

// Renders a glyph from Glyphs.js, or a user image when one is available.
// The Shape uses the curve renderer so it stays crisp at any scale without
// re-tessellating when the item is resized or zoomed.
Item {
    id: root

    property string kind: "bluetooth"
    property color color: "white"
    property real stroke: 1.6
    property url imageSource: ""

    readonly property bool _useImage: imageSource != "" && image.status === Image.Ready

    implicitWidth: 24
    implicitHeight: 24

    Shape {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: Math.min(root.width, root.height) / 24
        visible: !root._useImage
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: Glyphs.path(root.kind)
            }
        }
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.imageSource
        visible: root._useImage
        asynchronous: true
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.ceil(root.width * 2)
        sourceSize.height: Math.ceil(root.height * 2)
        smooth: true
        mipmap: true
    }
}
