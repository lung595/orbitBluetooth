import QtQuick
import qs.Common

// The sky behind the orbit, bottom to top: the desktop's glass veil, the
// starfield (it leans away from a dragged device, and drifts a little the way
// the camera went when a Listen together takes the center), the black hole drifting
// in the outer belt, and the dimming laid over them while a card is open.
// A click on this empty sky closes that card.
Item {
    id: backdrop
    required property var scene
    // The black hole's event horizon radius, which the drag gestures measure from
    readonly property real holeHorizon: blackHole.horizon

    // Desktop glass: a theme-tinted smoky veil that dissolves into the wallpaper
    Vignette {
        visible: backdrop.scene.glass
        color: Qt.tint(backdrop.scene.night.skyDeep, Theme.withAlpha(backdrop.scene.night.primary, 0.07))
        strength: backdrop.scene.prefs.desktopBackdrop
    }

    Starfield {
        id: stars
        x: -12 + backdrop.scene.centre.shift.x + (backdrop.scene.dragBody ? -(backdrop.scene.dragX - backdrop.scene.cx) * 0.025 : 0)
        y: -12 + backdrop.scene.centre.shift.y + (backdrop.scene.dragBody ? -(backdrop.scene.dragY - backdrop.scene.cy) * 0.025 : 0)
        width: backdrop.scene.width + 24
        height: backdrop.scene.height + 24
        clock: backdrop.scene.clock
        animate: backdrop.scene.motion && backdrop.scene.active
        shootingStars: backdrop.scene.prefs.shootingStars && backdrop.scene.awake
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

    BlackHole {
        id: blackHole
        scene: backdrop.scene
        sky: stars
        x: backdrop.scene.holeX - width / 2
        y: backdrop.scene.holeY - height / 2
        count: backdrop.scene.hiddenCount
        feed: backdrop.scene.holeFeed
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
            opacity: 0.4
        }
        Vignette {
            visible: backdrop.scene.glass
            color: "black"
            strength: 0.6
        }
    }

    // Click on empty space leaves focus mode
    MouseArea {
        anchors.fill: parent
        enabled: !!backdrop.scene.focusBody || backdrop.scene.hiddenOpen
        onClicked: {
            backdrop.scene.clearFocus();
            backdrop.scene.closeHidden();
        }
    }
}
