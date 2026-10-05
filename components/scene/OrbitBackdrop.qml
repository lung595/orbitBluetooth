import QtQuick
import qs.Common
import "Depth.js" as Depth

// The sky behind the orbit, bottom to top: the desktop's glass veil, the
// starfield (it leans away from a dragged device, and drifts a little the way
// the camera went when a Listen together takes the center), the black hole drifting
// in the outer belt, and the dimming laid over them while a card is open.
// While a Listen together has the centre the sky falls out of focus (D294):
// blurred, its light kept, in a soft glow of the sky's colour: a deep
// atmosphere, not black. The blur is kept as a texture (DecorDepth).
// A click on this empty sky steps back one level (OrbitFocus.stepBack): the
// card, then Fedora's view.
Item {
    id: backdrop
    required property var scene
    // 0 = sharp, 1 = full depth of field: how far the camera is on the group.
    // It is `away`, not `presence`: back on Fedora's view the group still
    // exists but the camera is on the host, so the sky is sharp again
    property real depth: scene.centre.away
    // The black hole's event horizon radius, which the drag gestures measure from
    readonly property real holeHorizon: blackHole.horizon

    // Desktop glass: a theme-tinted smoky veil that dissolves into the wallpaper
    // (stronger with the depth: blurring a smooth gradient would show nothing)
    Vignette {
        visible: backdrop.scene.glass
        color: Qt.tint(backdrop.scene.night.skyDeep, Theme.withAlpha(backdrop.scene.night.primary, 0.07))
        strength: Depth.veilStrength(backdrop.scene.prefs.desktopBackdrop, skyDepth.shown)
    }

    Starfield {
        id: stars
        x: -12 + backdrop.scene.centre.shift.x + (backdrop.scene.dragBody ? -(backdrop.scene.dragX - backdrop.scene.cx) * 0.025 : 0)
        y: -12 + backdrop.scene.centre.shift.y + (backdrop.scene.dragBody ? -(backdrop.scene.dragY - backdrop.scene.cy) * 0.025 : 0)
        width: backdrop.scene.width + 24
        height: backdrop.scene.height + 24
        clock: backdrop.scene.clock
        // Nothing twinkles or flies behind the blurred copy: it is a still texture
        animate: backdrop.scene.motion && backdrop.scene.active && !skyDepth.frozen
        shootingStars: backdrop.scene.prefs.shootingStars && backdrop.scene.awake && !skyDepth.frozen
        density: backdrop.scene.prefs.starDensity
        vignette: backdrop.scene.glass
        radius: backdrop.scene.cornerRadius
        inset: 12
        // The black hole, in the starfield's coordinates, for passing stars
        holeX: backdrop.scene.holeX - x
        holeY: backdrop.scene.holeY - y
        holeR: blackHole.visible ? backdrop.scene.holeHorizon : 0
        onSwallowed: backdrop.scene.holeFlashAt = backdrop.scene.fxTime
        Behavior on x {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutCubic
            }
        }
    }

    DecorDepth {
        id: skyDepth
        source: stars
        depth: backdrop.depth
        motion: backdrop.scene.motion
        token: [stars.tint, stars.tint2, stars.density, stars.vignette, stars.radius]
    }

    // The deep atmosphere the group stands in on a solid sky: a soft glow of the
    // accent behind it, so the blurred sky does not average to black. Static: it
    // only moves with the group (never animated) and only exists under a group.
    // The desktop glass has its veil instead (the wallpaper shows through)
    Loader {
        objectName: "atmosphere"
        readonly property var group: backdrop.scene.centre.group
        width: backdrop.scene.width * 0.95
        height: backdrop.scene.height * 0.85
        x: group.x - width / 2
        y: group.y - height / 2
        active: !backdrop.scene.glass && Depth.atmosphereAlpha(skyDepth.shown) > 0
        sourceComponent: Atmosphere {
            anchors.fill: parent
            night: backdrop.scene.night
            smoky: false
            strength: Depth.atmosphereAlpha(skyDepth.shown)
        }
    }

    BlackHole {
        id: blackHole
        scene: backdrop.scene
        sky: stars
        x: backdrop.scene.holeX - width / 2
        y: backdrop.scene.holeY - height / 2
        count: backdrop.scene.hiddenCount
        feed: backdrop.scene.holeFeed
        eye: backdrop.scene.holeEye
        spin: backdrop.scene.holeSpin
        // Brief brightening of the ring after swallowing a shooting star
        flash: Math.max(0, 1 - (backdrop.scene.fxTime - backdrop.scene.holeFlashAt) / 0.6) * 0.8
        visible: backdrop.scene.btOn && backdrop.scene.width > 0
        onClicked: backdrop.scene.hiddenOpen ? backdrop.scene.closeHidden() : backdrop.scene.openHidden()
        Behavior on feed {
            NumberAnimation {
                duration: 200
            }
        }
    }

    // The hole falls out of focus with the sky, except while a gesture needs it
    // lit (hovered, a device carried to it, its list open)
    DecorDepth {
        source: blackHole
        depth: backdrop.depth
        motion: backdrop.scene.motion
        hold: blackHole.hovered || backdrop.scene.holeFeed > 0 || backdrop.scene.hiddenOpen
        token: [blackHole.count, backdrop.scene.glass, backdrop.scene.prefs.holeStyle, backdrop.scene.prefs.showLabels]
    }

    // Dims the backdrop in focus mode (elliptical on glass: no hard edge)
    Item {
        anchors.fill: parent
        opacity: backdrop.scene.focusBody || backdrop.scene.hiddenOpen ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            NumberAnimation {
                duration: 400
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: !backdrop.scene.glass
            radius: backdrop.scene.cornerRadius
            color: "black"
            // Softer under a group: the sky behind it is already blurred and dark
            opacity: Depth.focusDim(0.4, skyDepth.shown)
        }
        Vignette {
            visible: backdrop.scene.glass
            color: "black"
            strength: 0.6
        }
    }

    // Click on empty space steps back one level
    MouseArea {
        anchors.fill: parent
        enabled: backdrop.scene.canStepBack
        onClicked: backdrop.scene.stepBack()
    }
}
