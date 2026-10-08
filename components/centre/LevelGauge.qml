import QtQuick
import QtQuick.Shapes
import "Gauge.js" as Gauge

// A level drawn as a gauge: an open arc of 270 degrees (Gauge.js) over a faint
// track, a soft gradient that turns along the arc with the level, a glow where it ends, faint marks
// every 10 % that light as the level passes them, and a round thumb with a
// halo. Static art: it is redrawn only when the level or a colour changes, and
// nothing in it animates.
Shape {
    id: gauge

    // Radius of the arc's centre line in px, the level 0..1 and the band's width
    property real radius: 56
    property real level: 0
    property real lineWidth: 5
    property color trackColor: "transparent"
    // The level's colour at the start and at the end of the arc (the same: flat)
    property color startColor: "white"
    property color endColor: startColor
    property color glowColor: "transparent"
    property color tickColor: "transparent"
    property color litColor: tickColor
    // The thumb's diameter in px (0: none), its color and the halo's
    property real thumbSize: 0
    property color thumbColor: "white"
    property color haloColor: "transparent"

    readonly property real mid: width / 2
    // Room around the band for the marks, the glow and the halo
    readonly property real margin: lineWidth + 14
    // The marks start just outside the band and are 3 px long (longer at 0, 50, 100 %)
    readonly property real tickFrom: radius + lineWidth / 2 + 3
    // Where the level ends, and the glow's radius there
    readonly property var end: Gauge.pointAt(mid, mid, radius, level)
    readonly property real glow: lineWidth * 3
    readonly property bool started: level > 0.004

    width: (radius + margin) * 2
    height: width
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: "transparent"
        fillColor: gauge.trackColor
        PathSvg {
            path: Gauge.band(gauge.mid, gauge.mid, gauge.radius, gauge.lineWidth, 0, 1)
        }
    }
    ShapePath {
        strokeColor: gauge.tickColor
        strokeWidth: 1.2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathSvg {
            path: Gauge.ticks(gauge.mid, gauge.mid, gauge.tickFrom, 3, gauge.level, false)
        }
    }
    ShapePath {
        strokeColor: gauge.litColor
        strokeWidth: 1.2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathSvg {
            path: Gauge.ticks(gauge.mid, gauge.mid, gauge.tickFrom, 3, gauge.level, true)
        }
    }
    // The glow: a round gradient that fades out, centred on the level's end
    ShapePath {
        strokeColor: "transparent"
        fillGradient: RadialGradient {
            centerX: gauge.end.x
            centerY: gauge.end.y
            centerRadius: gauge.glow
            focalX: centerX
            focalY: centerY
            GradientStop {
                position: 0
                color: gauge.started ? gauge.glowColor : "transparent"
            }
            GradientStop {
                position: 1
                color: Qt.rgba(gauge.glowColor.r, gauge.glowColor.g, gauge.glowColor.b, 0)
            }
        }
        PathAngleArc {
            centerX: gauge.end.x
            centerY: gauge.end.y
            radiusX: gauge.glow
            radiusY: gauge.glow
            startAngle: 0
            sweepAngle: 359.9
        }
    }
    // The level, filled and not stroked: a stroke cannot take a gradient. The
    // gradient is conical, so a place on the arc has the color of its angle, not
    // of its x (Qt's own gradient, drawn by the curve renderer: no shader of ours,
    // and static like the rest). A level of 0 draws nothing, not the round dot
    // of an empty band.
    ShapePath {
        strokeColor: "transparent"
        fillGradient: ConicalGradient {
            centerX: gauge.mid
            centerY: gauge.mid
            angle: Gauge.conic().from
            GradientStop {
                position: 0
                color: gauge.startColor
            }
            GradientStop {
                position: Gauge.conic().to
                color: gauge.endColor
            }
            GradientStop {
                position: 1
                color: gauge.endColor
            }
        }
        PathSvg {
            path: gauge.started ? Gauge.band(gauge.mid, gauge.mid, gauge.radius, gauge.lineWidth, 0, gauge.level) : ""
        }
    }

    // Sits on the end of the arc, so it follows the level with no animation
    Rectangle {
        visible: gauge.thumbSize > 0
        width: gauge.thumbSize + 6
        height: width
        radius: width / 2
        color: gauge.haloColor
        x: gauge.end.x - width / 2
        y: gauge.end.y - height / 2

        Rectangle {
            anchors.centerIn: parent
            width: gauge.thumbSize
            height: width
            radius: width / 2
            color: gauge.thumbColor
        }
    }
}
