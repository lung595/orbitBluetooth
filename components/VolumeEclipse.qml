import QtQuick
import QtQuick.Shapes
import qs.Common

// Mute as an eclipse: a shadow slides over the planet from the right and
// stops just short of covering it, leaving a thin lit crescent and a corona
// of light around the rim. Unmute and the shadow slides away. The shadow
// is the lens where the planet and a shadow disc of the same size overlap,
// so nothing is drawn outside the planet. One brief transition, then still.
Item {
    id: eclipse

    property real centerX: 0
    property real centerY: 0
    property real planetRadius: 0
    property bool muted: false
    property bool motion: true

    readonly property NightColors night: NightColors {}
    // 0 = no shadow, 1 = eclipse
    property real cover: muted ? 1 : 0
    Behavior on cover {
        enabled: eclipse.motion
        NumberAnimation {
            duration: 450
            easing.type: Easing.InOutCubic
        }
    }

    // How far the shadow's center is from the planet's: 2r (just off it) to
    // a sliver at full eclipse
    readonly property real r: planetRadius
    readonly property real offset: r * (2 - 1.88 * cover)
    readonly property real half: Math.sqrt(Math.max(0, r * r - offset * offset / 4))

    visible: cover > 0.01

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Corona: the planet's rim lit from behind the shadow
        ShapePath {
            strokeColor: Theme.withAlpha(eclipse.night.ringAccent, 0.16 * eclipse.cover)
            strokeWidth: 6
            fillColor: "transparent"
            PathAngleArc {
                centerX: eclipse.centerX
                centerY: eclipse.centerY
                radiusX: eclipse.r + 2
                radiusY: eclipse.r + 2
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: Theme.withAlpha(Qt.lighter(eclipse.night.ringAccent, 1.3), 0.7 * eclipse.cover)
            strokeWidth: 1.2
            fillColor: "transparent"
            PathAngleArc {
                centerX: eclipse.centerX
                centerY: eclipse.centerY
                radiusX: eclipse.r + 1
                radiusY: eclipse.r + 1
                startAngle: 0
                sweepAngle: 360
            }
        }
        // The shadow: the lens between the planet and the shadow disc. From
        // the top crossing, along the shadow's edge to the bottom crossing,
        // then back up along the planet's edge.
        ShapePath {
            strokeColor: "transparent"
            fillColor: Theme.withAlpha(eclipse.night.sky, eclipse.night.lift ? 0.5 : 0.78)
            startX: eclipse.centerX + eclipse.offset / 2
            startY: eclipse.centerY - eclipse.half
            PathArc {
                x: eclipse.centerX + eclipse.offset / 2
                y: eclipse.centerY + eclipse.half
                radiusX: eclipse.r
                radiusY: eclipse.r
                direction: PathArc.Counterclockwise
            }
            PathArc {
                x: eclipse.centerX + eclipse.offset / 2
                y: eclipse.centerY - eclipse.half
                radiusX: eclipse.r
                radiusY: eclipse.r
                direction: PathArc.Counterclockwise
            }
        }
    }
}
