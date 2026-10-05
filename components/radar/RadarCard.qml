import QtQuick
import qs.Common
import qs.Widgets
import "../card"

// The radar's glass card, like the detail card's: a frosted surface, the hero's
// name and what it is in the header, a way back to the group's level when the
// hero is a member, and a way out that can always be seen. It only draws, and
// says which button was pressed.
Item {
    id: card

    required property PaperColors paper
    property string title: ""
    property string subtitle: ""
    // Whether the way back to the group's level is offered
    property bool canGoBack: false

    signal back
    signal closed

    Rectangle {
        anchors.fill: parent
        radius: Math.round(width * 0.05)
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
        x: Theme.spacingM
        y: Theme.spacingM
        onClicked: card.back()
    }
    Column {
        x: card.canGoBack ? backButton.x + backButton.width + Theme.spacingS : Theme.spacingL
        y: Theme.spacingM
        width: parent.width - x - closeButton.width - Theme.spacingL
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
        x: parent.width - width - Theme.spacingM
        y: Theme.spacingM
        onClicked: card.closed()
    }
}
