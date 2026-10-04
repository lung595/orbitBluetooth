pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import "../device"
import "../noise"
import "../volume"
import "CardStatus.js" as CardStatus
import "Charge.js" as Charge
import "../common/Pictures.js" as Pictures

// Frosted detail card. The focused device glyph is not drawn here: the real
// orbiting body flies onto the card's top edge and scales up, so it breaks
// out of the frame (see DeviceBody.focused).
Item {
    id: card
    readonly property PaperColors paper: PaperColors {}

    required property var scene
    readonly property var body: scene.focusBody
    readonly property var device: body ? body.device : null
    property bool picking: false
    property bool confirmForget: false
    // Headsets with noise control trade the battery graph for the ANC panel
    readonly property bool ancShown: !picking && scene.ancCapable(body)

    readonly property color ink: card.paper.ink
    readonly property color muted: card.paper.fg(0.42)

    // Time to full / time left, e.g. "≈ 2 h 08 to full"
    readonly property string timeText: body?.connected && (body?.battery ?? -1) >= 0 ? Charge.timeText(body.charge ?? null, body.charging) : ""

    // Per-part batteries reported by the headset (earbuds and case)
    readonly property var parts: body?.ancFresh ? (body.ancInfo?.state?.battery ?? null) : null
    readonly property bool trioShown: !picking && !!parts && !!(parts.left || parts.right || parts.case)

    // Charging / drain stats, shown in the battery card, or under the noise
    // control panel for headsets with ANC
    readonly property var statItems: body?.connected ? Charge.statItems(body.charge ?? null, body.charging, scene.now) : []

    implicitHeight: frameContent.implicitHeight + scene.focusOverlap + Theme.spacingL

    onBodyChanged: {
        picking = false;
        confirmForget = false;
        scene.renaming = false;
    }

    // The device's two volumes; its picture of the sound runs only while
    // the card is on screen
    CardVolume {
        id: volumes
        route: card.scene.audioRoute
        prefs: card.scene.prefs
        address: card.body && card.body.connected ? card.body.address : ""
        seen: card.visible && card.scene.awake && !card.picking
        live: seen && !card.volumeFolded
    }
    // In the menus the volumes start as a thin line, so the card fits
    // without scrolling; a click unfolds the scope
    readonly property bool volumeFolded: card.scene.foldVolume && !card.scene.volumeUnfolded

    // Swallow clicks so they don't reach the scene's "click outside" handler
    MouseArea {
        anchors.fill: parent
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.round(width * 0.075)
        color: card.paper.fill(0.86)
        border.width: 1
        border.color: card.paper.fg(0.07)
    }

    CardActions {
        card: card
    }

    // Scrolls when the host is short (compact Control Center tile)
    Flickable {
        x: Theme.spacingL
        y: card.scene.focusOverlap
        width: parent.width - Theme.spacingL * 2
        // Bottom margin equals the side margins (and matches implicitHeight)
        height: parent.height - y - Theme.spacingL
        contentHeight: frameContent.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: frameContent
            width: parent.width
            spacing: 2

            NameBox {
                card: card
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: CardStatus.kindLine(card.body)
                color: card.muted
                font.pixelSize: Theme.fontSizeSmall
            }

            // What the sound is: connection, codec, rate (D260)
            FactsLine {
                visible: shown && !card.picking
                width: parent.width
                height: implicitHeight
                source: volumes
                ink: card.ink
                muted: card.muted
            }

            // One gap between the title block, the battery and the controls
            Item {
                width: 1
                height: Theme.spacingS
            }

            VolumeSection {
                width: parent.width
                card: card
                levels: volumes
            }

            // Earbuds with a case: case, left and right with a bar each
            Loader {
                width: parent.width
                active: card.trioShown
                visible: active
                sourceComponent: EarbudsTrio {
                    width: parent ? parent.width : 0
                    parts: card.parts
                    name: card.body?.model ?? ""
                    caption: card.timeText
                    animate: card.scene.awake && card.scene.motion
                    time: card.scene.fxTime
                    caseImage: card.scene.prefs.partImageFor(card.device, "case")
                    leftImage: card.scene.prefs.partImageFor(card.device, "left")
                    rightImage: card.scene.prefs.partImageFor(card.device, "right")
                }
            }

            Loader {
                width: parent.width
                active: !card.picking
                visible: active
                sourceComponent: CardBattery {
                    width: parent ? parent.width : 0
                    card: card
                }
            }

            // With noise control, the stats stay with the battery, above the
            // ANC panel (without it they are part of the battery card)
            StatTiles {
                width: parent.width
                topPadding: Theme.spacingS
                stats: card.ancShown ? card.statItems : []
            }

            Loader {
                width: parent.width
                active: card.ancShown
                visible: active
                sourceComponent: AncPanel {
                    width: parent ? parent.width : 0
                    topPadding: Theme.spacingM
                    scene: card.scene
                    address: card.body?.address ?? ""
                }
            }

            // Credit of the downloaded picture: its licenses ask for it
            StyledText {
                width: parent.width
                visible: !card.picking && !!card.body?.picture?.credit
                text: visible ? Pictures.creditText(card.body.picture.credit) : ""
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: card.paper.fg(0.45)
                font.pixelSize: Theme.fontSizeSmall - 2
            }

            Loader {
                width: parent.width
                active: card.picking
                visible: active
                sourceComponent: GlyphPicker {
                    width: parent ? parent.width : 0
                    card: card
                }
            }
        }
    }
}
