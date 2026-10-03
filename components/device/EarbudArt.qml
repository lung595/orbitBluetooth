import QtQuick
import QtQuick.Shapes
import "Earbuds.js" as Earbuds

// One earbud or the case, drawn from Earbuds.js with soft shading and a
// highlight, or the user's own picture when one exists. Static art: it
// only redraws when its size or style changes.
Item {
    id: art

    property string part: "case"         // "case", "left" or "right"
    property var look: Earbuds.style("")
    property string imageSource: ""       // user picture, overrides the drawing
    property string fallbackSource: ""    // tried when imageSource is missing (mirrored)
    property bool _useFallback: false
    onImageSourceChanged: _useFallback = false

    readonly property var shape: part === "case" ? Earbuds.BOX[look.box] : Earbuds.BUD[look.bud]
    readonly property var colors: Earbuds.FINISH[look.finish]
    readonly property bool hasImage: picture.status === Image.Ready

    Image {
        id: picture
        anchors.fill: parent
        source: art._useFallback ? art.fallbackSource : art.imageSource
        visible: art.hasImage
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        sourceSize: Qt.size(Math.ceil(art.width * 2), Math.ceil(art.height * 2))
        mirror: art._useFallback
        onStatusChanged: if (status === Image.Error && !art._useFallback && art.fallbackSource)
            art._useFallback = true
    }

    // The right bud is the left one mirrored (around the item's middle:
    // a transform on the scaled Shape would mirror around the wrong point)
    Item {
        anchors.fill: parent
        visible: !art.hasImage
        transform: Scale {
            origin.x: art.width / 2
            xScale: art.part === "right" ? -1 : 1
        }

        Shape {
            width: 100
            height: 100
            scale: art.width / 100
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer

            // Ear tip, behind the body (pebble buds)
            ShapePath {
                strokeWidth: -1
                fillColor: art.shape.tip ? Qt.darker(art.colors[1], 1.3) : "transparent"
                PathSvg {
                    path: art.shape.tip || ""
                }
            }
            ShapePath {
                fillRule: ShapePath.WindingFill    // head + stem overlap without a hole
                strokeColor: Qt.rgba(1, 1, 1, 0.18)
                strokeWidth: 0.8
                fillGradient: LinearGradient {
                    x1: 20
                    y1: 5
                    x2: 80
                    y2: 95
                    GradientStop {
                        position: 0
                        color: art.colors[0]
                    }
                    GradientStop {
                        position: 1
                        color: art.colors[1]
                    }
                }
                PathSvg {
                    path: art.shape.body
                }
            }
            // Mesh, seam, LED
            ShapePath {
                strokeColor: Qt.rgba(0, 0, 0, 0.35)
                strokeWidth: 1
                fillColor: art.colors[2]
                PathSvg {
                    path: art.shape.detail
                }
            }
            // Specular highlight
            ShapePath {
                strokeColor: Qt.rgba(1, 1, 1, art.look.finish === "white" ? 0.9 : 0.35)
                strokeWidth: 2.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: art.shape.shine
                }
            }
        }
    }
}
