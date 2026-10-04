import QtQuick
import qs.Common
import qs.Widgets

// The device's name. Paired devices: click to rename, Enter to save, Escape
// to cancel, an empty name gives the device its own name back.
Item {
    id: nameBox
    required property var card
    readonly property bool canRename: card.body?.paired ?? false
    readonly property bool editing: card.scene.renaming && canRename
    width: parent.width
    height: nameLabel.implicitHeight + 6

    // Hover hint: a soft pill that hugs the name
    Rectangle {
        anchors.centerIn: nameLabel
        width: Math.min(nameBox.width, (nameBox.editing ? nameInput.contentWidth : nameLabel.contentWidth) + Theme.spacingM * 2)
        height: parent.height
        radius: height / 2
        color: nameBox.card.paper.fg(nameBox.editing ? 0.08 : 0.05)
        visible: nameBox.editing || nameHover.containsMouse
    }

    StyledText {
        id: nameLabel
        anchors.centerIn: parent
        width: parent.width - Theme.spacingM * 2
        horizontalAlignment: Text.AlignHCenter
        text: nameBox.card.body?.name ?? ""
        elide: Text.ElideRight
        color: nameBox.card.ink
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        visible: !nameBox.editing
    }

    MouseArea {
        id: nameHover
        anchors.fill: parent
        enabled: nameBox.canRename && !nameBox.editing
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: {
            nameInput.text = nameBox.card.body.name;
            nameBox.card.scene.renaming = true;
            nameInput.forceActiveFocus();
            nameInput.selectAll();
        }
    }

    TextInput {
        id: nameInput
        anchors.centerIn: parent
        width: parent.width - Theme.spacingM * 2
        horizontalAlignment: TextInput.AlignHCenter
        visible: nameBox.editing
        color: nameBox.card.ink
        selectionColor: Theme.withAlpha(Theme.primary, 0.35)
        selectedTextColor: nameBox.card.ink
        font.family: nameLabel.font.family
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        // BlueZ names are at most 248 bytes
        maximumLength: 60
        clip: true
        // Enter, or clicking elsewhere, saves. Escape (handled here
        // and by the scene's Shortcut) clears `renaming` first, so
        // the focus loss that follows saves nothing.
        onEditingFinished: {
            if (nameBox.card.scene.renaming)
                nameBox.card.scene.rename(nameBox.card.body, text);
        }
        Keys.onEscapePressed: event => {
            nameBox.card.scene.renaming = false;
            event.accepted = true;
        }
    }
}
