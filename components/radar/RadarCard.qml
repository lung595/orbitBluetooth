import QtQuick
import qs.Common
import qs.Widgets
import "../card"

// The radar's glass card, like the detail card's: a frosted surface, the hero's
// name and what it is in the header, a way back to the group's level when the
// hero is a member, and a way out that can always be seen. It only draws, and
// says which button was pressed. It fills the scene exactly (same rounded
// rectangle, so the host's frame around it is the one around the sky).
Item {
    id: card

    required property PaperColors paper
    // The scene's own corner radius, so the card's edge is the scene's edge
    property real radius: 0
    property string title: ""
    property string subtitle: ""
    // Whether the way back to the group's level is offered
    property bool canGoBack: false

    signal back
    signal closed

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: card.paper.fill(0.95)
        border.width: 1
        border.color: card.paper.fg(0.07)
    }
    // A click on the card is not a click beside it: it does not close the radar
    MouseArea {
        anchors.fill: parent
    }

    CardButton {
        id: backButton
        visible: card.canGoBack
        paper: card.paper
        icon: "arrow_back"
        x: Theme.spacingL
        y: Theme.spacingL
        onClicked: card.back()
    }
    Column {
        x: card.canGoBack ? backButton.x + backButton.width + Theme.spacingS : Theme.spacingL
        y: Theme.spacingL
        width: parent.width - x - closeButton.width - Theme.spacingL - Theme.spacingS
        spacing: 1
        StyledText {
            width: parent.width
            elide: Text.ElideRight
            text: card.title
            color: card.paper.ink
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
        }
        StyledText {
            width: parent.width
            elide: Text.ElideRight
            text: card.subtitle
            color: card.paper.fg(0.5)
            font.pixelSize: Theme.fontSizeSmall
        }
    }
    CardButton {
        id: closeButton
        paper: card.paper
        icon: "close"
        x: parent.width - width - Theme.spacingL
        y: Theme.spacingL
        onClicked: card.closed()
    }
}
