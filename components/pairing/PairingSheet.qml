import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets

// The pairing sheet: a tall card that unfolds from the bar when new
// headphones are in pairing mode. NewDeviceWatch owns the state and the
// actions; this is the look, put together from its parts:
// PairingSkin (colours of the two skins, dark and light), PairingMotion
// (time and entrance), PairingSky and PairingPlanet (the scene the device
// floats in), PairingHeader, PairingStage (the device), PairingIdentity,
// PairingMiddle and PairingButton.
Item {
    id: root

    // "offer", "pairing", "connecting", "done" or "failed"
    property string phase: "offer"
    property string name: ""
    property string subtitle: ""
    // Shown when pairing failed, in plain words (Offer.errorText)
    property string errorText: "Could not connect. Is it still in pairing mode?"
    // The guide section that explains the failure
    property string errorAnchor: "if-it-does-not-connect"
    property string kind: "headphonesSlim"
    property url pictureSource: ""
    property string credit: ""
    property int battery: -1
    // [{icon, value, label}] from Offer.features
    property var features: []
    // Noise-control modes offered once connected, and the current one
    property var ancModes: []
    property string ancMode: ""
    // 1 -> 0 while the offer waits for an answer
    property real life: 1
    // Devices waiting behind this one
    property int stacked: 0
    property bool shown: true
    property bool reduceMotion: false
    // Locked or screens off (set by the window): nothing moves
    property bool asleep: false
    // Follows DMS; the preview can force it
    property bool light: Theme.isLightMode

    signal accepted
    signal later
    signal ignored
    signal retry
    signal cancelled
    // "Pair anyway" after the keyboard-profile question (phase "confirm")
    signal confirmed
    signal renamed(string text)
    signal modeRequested(string mode)

    readonly property bool busy: phase === "pairing" || phase === "connecting"
    readonly property Item card: card
    // Where clicks are taken: the card's resting place. The card itself is
    // scaled while it unfolds, and a window mask built from it kept that
    // squashed size, so the bottom of the card (Connect, Don't offer again)
    // let clicks through to the window below.
    readonly property Item hitArea: hitArea
    Item {
        id: hitArea
        x: root.pad
        y: root.topGap
        width: root.cardWidth
        height: root.cardHeight
    }
    readonly property bool hovered: hover.hovered
    // Typing a new name (the window gives the sheet the keyboard meanwhile)
    property bool renaming: false
    // Leaving after a connection: the sheet folds back into the bar's corner
    property bool exitToBar: false

    readonly property real cardWidth: 340
    readonly property real cardHeight: 520
    // Room for the shadow (kept short so the card can sit close to the screen
    // edge) and the cards peeking below
    readonly property real pad: 16
    // Gap between the card and the screen's right edge: the bar's own, so
    // both line up (the shadow simply runs off the screen there)
    property real rightGap: pad
    // Gap under the bar
    property real topGap: 6
    implicitWidth: cardWidth + pad + rightGap
    implicitHeight: cardHeight + pad + 44

    PairingMotion {
        id: motion
        shown: root.shown
        reduceMotion: root.reduceMotion
        asleep: root.asleep
        phase: root.phase
        battery: root.battery
        hovering: hover.hovered
        pointerX: hover.point.position.x / root.cardWidth
        pointerY: hover.point.position.y / root.cardHeight
        flash: stage.flash
    }
    PictureColor {
        id: picture
        source: root.pictureSource
    }
    PairingSkin {
        id: skin
        light: root.light
        picked: picture.found
    }

    // Enter: connect (or retry, or done); Escape: later (or cancel)
    focus: true
    Keys.onPressed: event => {
        if (renaming)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (phase === "offer")
                accepted();
            else if (phase === "failed")
                retry();
            else if (phase === "done")
                later();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            if (busy)
                cancelled();
            else
                later();
            event.accepted = true;
        }
    }

    // --- The next devices, peeking below like a stack of cards ------------------
    Repeater {
        model: Math.min(2, root.stacked)
        Rectangle {
            id: peek
            required property int index
            readonly property real k: index + 1
            width: root.cardWidth * (1 - 0.06 * k)
            height: 40
            x: card.x + (root.cardWidth - width) / 2
            y: card.y + root.cardHeight - height + 7 * k
            z: -k
            radius: card.radius * (1 - 0.06 * k)
            color: Qt.tint(skin.planetLow, Theme.withAlpha(skin.inkBase, skin.light ? 0.02 + 0.03 * k : 0.04 + 0.03 * k))
            border.width: 1
            border.color: skin.ink(skin.light ? 0.08 : 0.1)
            opacity: motion.reveal * (1 - 0.25 * peek.index)
        }
    }

    // --- Card ----------------------------------------------------------------------
    Item {
        id: card
        width: root.cardWidth
        height: root.cardHeight
        x: root.pad
        y: root.topGap
        readonly property real radius: 28
        // Where the planet's limb crosses the middle of the card
        readonly property real horizon: 222
        // Unfolds downwards from the bar; after a connection it folds back
        // into the corner it came from
        opacity: Math.min(1, motion.reveal * 1.6)
        transform: [
            Scale {
                origin.x: root.exitToBar ? card.width : card.width / 2
                origin.y: 0
                xScale: root.exitToBar ? 0.12 + 0.88 * motion.reveal : 0.93 + 0.07 * motion.reveal
                yScale: root.exitToBar ? 0.12 + 0.88 * motion.reveal : 0.78 + 0.22 * motion.reveal
            },
            Translate {
                y: root.exitToBar ? 0 : -16 * (1 - motion.reveal)
            }
        ]

        HoverHandler {
            id: hover
        }

        // A click on the card's background takes the focus back from the
        // name field, which keeps what was typed
        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                root.forceActiveFocus();
                mouse.accepted = false;
            }
        }

        // Shadow: neutral and deep on the night, soft and tinted on the pearl
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: skin.planetLow
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: skin.light ? Qt.tint(Qt.rgba(0.1, 0.1, 0.16, 0.22), Theme.withAlpha(skin.accent, 0.12)) : Qt.rgba(0, 0, 0, 0.55)
                // Short enough to fit in the sheet's own margin
                blurMax: 24
                shadowBlur: 0.7
                shadowVerticalOffset: 8
            }
        }

        // The scene, painted inside the rounded card
        Item {
            id: inside
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cardMask
            }

            PairingSky {
                anchors.fill: parent
                look: skin
                motion: motion
                horizon: card.horizon
            }
            PairingPlanet {
                anchors.fill: parent
                look: skin
                horizon: card.horizon
            }
        }

        Rectangle {
            id: cardMask
            anchors.fill: parent
            radius: card.radius
            visible: false
            layer.enabled: true
        }

        // Hairline outline
        Rectangle {
            anchors.fill: parent
            radius: card.radius
            color: "transparent"
            border.width: 1
            border.color: skin.ink(skin.light ? 0.08 : 0.09)
        }

        // --- Header: status, queue, close (PairingHeader.qml) ----------------------
        PairingHeader {
            width: card.width
            height: 46
            sheet: root
            look: skin
            motion: motion
        }

        // --- Stage: the device, its orbit and its effects (PairingStage.qml) -------------
        PairingStage {
            id: stage
            y: 46
            width: card.width
            height: card.horizon - y
            sheet: root
            look: skin
            motion: motion
        }

        // --- Identity, on the planet (PairingIdentity.qml) -------------------------------
        PairingIdentity {
            y: card.horizon + 22
            width: card.width
            opacity: motion.stagger(3)
            transform: Translate {
                y: (1 - motion.stagger(3)) * 14
            }
            sheet: root
            look: skin
        }

        // --- Middle: tiles, steps or quick actions (PairingMiddle.qml) ------------------
        PairingMiddle {
            x: 16
            y: 324
            width: card.width - 32
            height: 76
            opacity: motion.stagger(4)
            transform: Translate {
                y: (1 - motion.stagger(4)) * 14
            }
            sheet: root
            look: skin
        }

        // --- Main button and the quiet links under it (PairingButton.qml) -------------
        PairingButton {
            y: 422
            width: card.width
            sheet: root
            look: skin
            motion: motion
        }

        // Credit of a downloaded picture: its license asks for it
        StyledText {
            visible: root.credit !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: card.horizon - 18
            width: card.width - 40
            horizontalAlignment: Text.AlignHCenter
            text: "Picture " + root.credit
            elide: Text.ElideMiddle
            color: skin.ink(0.32)
            font.pixelSize: Theme.fontSizeSmall - 3
        }
    }
}
