import QtQuick
import qs.Common

// The two rows of corner buttons on the detail card. Left: the card itself
// (back, look); right: the device (connect, hide, forget). Two sides keep
// the header balanced around the glyph.
Item {
    id: actions
    required property var card
    readonly property PaperColors paper: card.paper

    anchors.fill: parent

    Row {
        x: Theme.spacingM
        y: Theme.spacingM
        spacing: Theme.spacingXS

        CardButton {
            paper: actions.paper
            icon: "arrow_back"
            onClicked: actions.card.scene.clearFocus()
        }
        CardButton {
            paper: actions.paper
            icon: "palette"
            active: actions.card.picking
            onClicked: actions.card.picking = !actions.card.picking
        }
    }

    Row {
        x: parent.width - width - Theme.spacingM
        y: Theme.spacingM
        spacing: Theme.spacingXS

        CardButton {
            paper: actions.paper
            visible: !!actions.card.device
            icon: actions.card.body?.phase === "connecting" ? "close" : actions.card.body?.connected ? "link_off" : "link"
            onClicked: {
                if (actions.card.body.phase === "connecting")
                    actions.card.scene.cancelConnect(actions.card.body);
                else if (actions.card.body.connected)
                    actions.card.scene.startDisconnect(actions.card.body);
                else
                    actions.card.scene.startConnect(actions.card.body);
            }
        }
        // Into the black hole: gone from the orbit, still connected
        CardButton {
            paper: actions.paper
            icon: "visibility_off"
            onClicked: actions.card.scene.hideBody(actions.card.body)
        }
        CardButton {
            paper: actions.paper
            visible: actions.card.body?.paired ?? false
            icon: actions.card.confirmForget ? "delete_forever" : "delete"
            danger: true
            active: actions.card.confirmForget
            onClicked: {
                if (!actions.card.confirmForget) {
                    actions.card.confirmForget = true;
                    return;
                }
                actions.card.scene.forget(actions.card.body);
            }
        }
    }
}
