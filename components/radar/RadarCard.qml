import QtQuick
import qs.Common
import qs.Widgets
import "../card"

// The radar's card, the detail card's frame: the same rounded rectangle and edge,
// the picture of the hero breaking out of its top edge, its name and what it is
// under it, round buttons in the corners (back to the group's level when the hero
// is a member, and a way out that can always be seen). It only draws, and says
// which button was pressed. The dials go in the space under the header; the
// view that holds it places them.
Item {
    id: card

    required property var scene
    required property PaperColors paper
    // What the hero is, and the picture to carry when it has no planet to fly (the
    // radar's hero is a group or a wired output: RadarGlyph)
    property string title: ""
    property string subtitle: ""
    property var heroInfo: ({})
    property bool carried: false
    property bool round: true
    property string heroKey: ""
    // Whether the way back to the group's level is offered
    property bool canGoBack: false

    // Where the dials start: under the picture and the two lines of the header
    readonly property real titleHeight: heading.implicitHeight
    readonly property real headerHeight: scene.focusOverlap + titleHeight + Theme.spacingS

    signal back
    signal closed

    // A click on the card is not a click beside it: it does not close the radar
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

    RadarGlyph {
        x: (card.width - width) / 2
        y: card.scene.focusGlyphLift - height / 2
        z: 1
        night: card.scene.night
        info: card.heroInfo
        size: card.scene.focusGlyphSize
        round: card.round
        carried: card.carried
        key: card.heroKey
        motion: card.scene.motion
    }

    CardButton {
        visible: card.canGoBack
        paper: card.paper
        icon: "arrow_back"
        x: Theme.spacingM
        y: Theme.spacingM
        onClicked: card.back()
    }
    CardButton {
        paper: card.paper
        icon: "close"
        x: parent.width - width - Theme.spacingM
        y: Theme.spacingM
        onClicked: card.closed()
    }

    Column {
        id: heading
        x: Theme.spacingL
        y: card.scene.focusOverlap
        width: parent.width - Theme.spacingL * 2
        spacing: 2
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: card.title
            color: card.paper.ink
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
        }
        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: card.subtitle
            color: card.paper.fg(0.42)
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
