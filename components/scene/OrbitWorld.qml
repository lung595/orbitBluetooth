import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.Widgets
import "../card"
import "../centre"
import "../device"

// The orbit itself, back to front: the two orbits, the radar ping, the
// connection waves, the host core and its name, the device bodies, and the
// cards that slide up over them. Bodies and cards are siblings so a
// focused body can sit above its card as the card's glyph. While a Listen
// together has the centre, the host's system (its orbits and waves, its core
// and the bodies outside the group) revolves around the group as a sun.
Item {
    id: world
    required property var scene
    required property ListModel model   // one entry per device body
    readonly property alias bodies: bodyRepeater
    readonly property alias focusCard: focusCardItem
    readonly property alias tetherLayer: tetherLayerItem

    readonly property real dim: world.scene.focusBody || world.scene.hiddenOpen ? 0.12 : 1
    readonly property var centre: world.scene.centre

    // A ring wave from the connected orbit: outward when a device connects,
    // inward when one leaves. Two waves, so a quick second edge still shows.
    function emitWave(outward) {
        const w = waveA.busy ? waveB : waveA;
        w.fire(outward);
    }

    function pulseCore() {
        core.pulse();
    }

    // A device drawn under this scene point, if any (devices passing behind
    // the core still get their clicks)
    function bodyAt(x, y) {
        for (let i = 0; i < bodyRepeater.count; i++) {
            const b = bodyRepeater.itemAt(i);
            if (b && !b.leaving && Math.hypot(x - b.px, y - b.py) < b.diameter * b.baseScale / 2)
                return b;
        }
        return null;
    }

    // The host's orbits and the waves thrown from them, drawn once in the
    // scene's own layout and carried (moved and scaled, nothing redrawn) to
    // where the sun is: its path and size come from the centre
    Item {
        id: systemLayer
        width: parent.width
        height: parent.height
        transformOrigin: Item.TopLeft
        scale: world.centre.system.k
        x: world.centre.system.x - world.scene.cx * scale
        y: world.centre.system.y - world.scene.cy * scale

        // Outer field: dotted orbit
        Repeater {
            model: 64
            Rectangle {
                readonly property real a: index / 64 * Math.PI * 2
                readonly property real r: (1 + world.scene.outerMinNorm) / 2
                x: world.scene.cx + Math.cos(a) * world.scene.rx * r - 0.75
                y: world.scene.cy + Math.sin(a) * world.scene.ry * r - 0.75
                width: 1.5
                height: 1.5
                radius: 0.75
                color: "white"
                opacity: 0.2 * world.dim * (world.scene.btOn ? 1 : 0.3)
                visible: world.scene.width > 0
            }
        }

        // Connected orbit ring
        Shape {
            id: innerRing
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: world.dim * (world.scene.btOn ? 1 : 0.3)

            readonly property bool guiding: !!world.scene.dragBody && !world.scene.dragBody.holding
            readonly property bool armedIn: guiding && world.scene.dragBody.armed

            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }

            ShapePath {
                strokeColor: innerRing.armedIn ? Theme.withAlpha(world.scene.night.primary, 0.85) : innerRing.guiding ? Theme.withAlpha(world.scene.night.primary, 0.45) : world.scene.night.ink(0.1)
                strokeWidth: innerRing.armedIn ? 1.8 : 1
                fillColor: innerRing.armedIn ? Theme.withAlpha(world.scene.night.primary, 0.05) : "transparent"
                PathAngleArc {
                    centerX: world.scene.cx
                    centerY: world.scene.ringCy
                    radiusX: world.scene.rx * world.scene.innerNorm
                    radiusY: world.scene.ringRy
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        // Connection waves (elliptical, follow the orbit's perspective)
        RingWave {
            id: waveA
            scene: world.scene
        }
        RingWave {
            id: waveB
            scene: world.scene
        }
    }

    // Radar ping while discovering
    Rectangle {
        id: ping
        x: world.centre.host.x - width / 2
        y: world.centre.host.y - height / 2
        width: world.scene.coreSize
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: world.scene.night.primary
        visible: world.scene.discovering && world.scene.active && world.scene.motion
        // One ring every 2.6 s from the effects clock: grows (OutCubic)
        // while it fades (OutQuad)
        readonly property real t: (world.scene.fxTime % 2.6) / 2.6
        scale: (1 + 2.2 * (1 - Math.pow(1 - t, 3))) * world.centre.host.scale
        opacity: 0.35 * (1 - t) * (1 - t) * (world.centre.hostAway ? 0.6 : 1)
    }

    Item {
        id: tetherLayerItem
        anchors.fill: parent
    }

    // A Listen together at the centre (OrbitCentre): the beams under the
    // planets, and the volume ring above the far side of the orbit
    Loader {
        anchors.fill: parent
        z: 5
        active: world.centre.shown
        opacity: world.dim
        sourceComponent: CentreBeams {
            centre: world.centre
        }
    }
    Loader {
        anchors.fill: parent
        z: 60
        active: world.centre.shown
        opacity: world.dim
        sourceComponent: CentreRing {
            centre: world.centre
        }
    }
    // Above every planet: a device passing in front must not hide what the
    // group listens on
    Loader {
        anchors.fill: parent
        z: 5000
        active: world.centre.shown
        opacity: world.dim
        sourceComponent: CentreLabel {
            centre: world.centre
        }
    }

    // Host core
    OrbitCore {
        id: core
        scene: world.scene
        world: world
        z: world.centre.hostZ
    }

    LabelGlow {
        x: hostName.x + hostName.width / 2 - width / 2
        y: hostName.y + hostName.height / 2 - height / 2
        z: world.centre.hostZ - 1
        spanX: hostName.width + 26
        spanY: hostName.height + 12
        color: world.scene.night.primary
        strength: 0.16
        opacity: hostName.opacity
        visible: hostName.text !== ""
    }

    StyledText {
        id: hostName
        anchors.horizontalCenter: core.horizontalCenter
        // Under the host. It fades as the group takes the centre: the sun is small
        // then, and a name half hidden behind the group reads as a glitch
        y: world.centre.host.y + core.height / 2 * world.centre.host.scale + 4
        z: world.centre.hostZ
        text: UserInfoService.hostname || ""
        color: world.scene.night.ink(0.72)
        font.pixelSize: Math.max(9, Math.round(world.scene.coreSize * 0.14))
        font.letterSpacing: 0.6
        opacity: world.scene.focusBody ? 0 : 1 - world.centre.away
    }

    Repeater {
        id: bodyRepeater
        model: world.model
        delegate: DeviceBody {
            scene: world.scene
        }
    }

    // Black hole contents, slides up like the focus card
    HiddenCard {
        scene: world.scene
        z: 15000
        width: world.scene.focusCardWidth
        height: Math.min(implicitHeight, world.scene.height - Theme.spacingM * 2)
        x: (world.scene.width - width) / 2
        y: world.scene.hiddenOpen ? world.scene.height - height - Theme.spacingM : world.scene.height + 20
        opacity: world.scene.hiddenOpen ? 1 : 0
        visible: opacity > 0.01

        Behavior on y {
            NumberAnimation {
                duration: 420
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 260
            }
        }
    }

    // Focus card (bodies are siblings, so the focused glyph can sit above it)
    // Over the focused glyph: click to mute, wheel for the volume
    PlanetControl {
        scene: world.scene
        z: 20001
    }

    FocusCard {
        id: focusCardItem
        scene: world.scene
        z: 15000
        width: world.scene.focusCardWidth
        height: Math.min(implicitHeight, world.scene.height - world.scene.focusHeadroom - Theme.spacingM)
        x: (world.scene.width - width) / 2
        y: world.scene.focusBody ? world.scene.height - height - Theme.spacingM : world.scene.height + 20
        opacity: world.scene.focusBody ? 1 : 0
        visible: opacity > 0.01

        Behavior on y {
            NumberAnimation {
                duration: 480
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }
    }
}
