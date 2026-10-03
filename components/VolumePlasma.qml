import QtQuick
import QtQuick.Shapes
import qs.Common
import "Volume.js" as Volume
import "VolumeFx.js" as Fx

// The volume ring's level, drawn as a band of aurora: a ribbon of light
// whose edges ripple like a curtain, cooler at its start (tertiary) and
// glowing toward the moon (primary, then near white). The ripple only moves
// while the ring's clock runs (the volume is changing); at rest the band is
// still and costs nothing.
Shape {
    id: plasma

    property real centerX: 0
    property real centerY: 0
    property real radius: 0
    property real thickness: 5
    property real level: 0 // 0..1, how much of the ring is lit
    property real phase: 0 // drift of the ripple, advanced by the clock
    property real energy: 0 // 0..1, how fast the volume is moving
    property bool motion: true
    property bool muted: false

    readonly property NightColors night: NightColors {}
    // A still band ripples a little; a fast drag makes it flare
    readonly property real amp: motion ? 0.35 + 1.3 * energy : 0
    // The conical gradient turns counter-clockwise from 240° (the ring's
    // start, 120° clockwise on screen): position 1 is the start, and the
    // moon sits at 1 - (300/360) * level
    readonly property real head: 1 - Volume.sweep / 360 * Math.max(0.001, level)

    preferredRendererType: Shape.CurveRenderer

    function polyline(pts) {
        return pts.map(p => Qt.point(p.x, p.y));
    }

    // Track: the whole ring, faint, so the gap still reads at 0 %
    ShapePath {
        strokeColor: Theme.withAlpha(plasma.night.ringAccent, plasma.muted ? 0.1 : 0.16)
        strokeWidth: 2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: plasma.centerX
            centerY: plasma.centerY
            radiusX: plasma.radius
            radiusY: plasma.radius
            startAngle: Volume.start
            sweepAngle: Volume.sweep
        }
    }
    // Glow: the light the aurora throws around itself, stronger when it moves
    ShapePath {
        strokeColor: Theme.withAlpha(plasma.night.ringAccent, plasma.muted ? 0 : 0.08 + 0.12 * plasma.energy)
        // Fixed width: only its color follows the energy, so the arc is not
        // rebuilt on every frame
        strokeWidth: plasma.thickness + 9
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
            centerX: plasma.centerX
            centerY: plasma.centerY
            radiusX: plasma.radius
            radiusY: plasma.radius
            startAngle: Volume.start
            sweepAngle: Math.max(0.01, Volume.sweep * plasma.level)
        }
    }
    // The band itself
    ShapePath {
        strokeColor: "transparent"
        fillGradient: ConicalGradient {
            centerX: plasma.centerX
            centerY: plasma.centerY
            angle: 240
            GradientStop {
                position: 0
                color: Theme.withAlpha(plasma.night.ringAccent, 0.85)
            }
            GradientStop {
                position: plasma.head
                color: Theme.withAlpha(Qt.lighter(plasma.night.ringAccent, 1.6), 0.85)
            }
            GradientStop {
                position: plasma.head + (1 - plasma.head) * 0.45
                color: Theme.withAlpha(plasma.night.ringAccent, 0.6)
            }
            GradientStop {
                position: 1
                color: Theme.withAlpha(plasma.night.both(Theme.tertiary), 0.28)
            }
        }
        PathPolyline {
            path: plasma.polyline(Fx.band(plasma.centerX, plasma.centerY, plasma.radius, plasma.thickness, Volume.start, Volume.sweep, plasma.level, plasma.phase, plasma.amp))
        }
    }
    // A bright filament runs through the middle, like the core of a curtain
    ShapePath {
        strokeColor: Theme.withAlpha(plasma.night.ink(1), 0.25 + 0.3 * plasma.energy)
        strokeWidth: 1
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathPolyline {
            path: plasma.polyline(Fx.filament(plasma.centerX, plasma.centerY, plasma.radius, Volume.start, Volume.sweep, plasma.level, plasma.phase, plasma.amp))
        }
    }
}
