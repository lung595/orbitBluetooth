import QtQuick
import qs.Common
import qs.Widgets

// The search field on top of the settings page. It only edits `view.query`:
// the page filters itself from there. Esc clears, a second Esc leaves the
// field, Enter opens the best match.
Rectangle {
    id: field

    required property var view

    // The second Esc: the field lets go and the page takes the keys back
    signal released

    function focusField() {
        input.forceActiveFocus();
        input.selectAll();
    }

    readonly property bool typed: view.query !== ""

    // 44 px tall: the touch target of the spec (40 drawn + 2 px each side)
    height: 44
    radius: height / 2
    color: Theme.surfaceContainerHigh
    // At rest the opaque outline is the boundary of the field (3.6:1 on the
    // field in the light theme; a see-through one fell to 2.7:1). Typing or
    // keyboard focus: 2 px primary.
    border.width: typed || input.activeFocus ? 2 : 1
    border.color: typed || input.activeFocus ? Theme.primary : hover.hovered ? Theme.withAlpha(Theme.surfaceText, 0.5) : Theme.outline

    HoverHandler {
        id: hover
    }

    DankIcon {
        id: glass
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 20
        color: field.typed ? Theme.primary : Theme.surfaceVariantText
    }

    TextInput {
        id: input
        anchors.left: glass.right
        anchors.leftMargin: Theme.spacingS
        anchors.right: hint.left
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        selectionColor: Theme.primary
        selectedTextColor: Theme.primaryText
        // Long queries are cut: a search of 70 settings never needs more
        maximumLength: 80
        Accessible.role: Accessible.EditableText
        Accessible.name: "Search settings"
        onTextChanged: field.view.query = text
        onAccepted: field.view.openFirst()
        Keys.onEscapePressed: {
            if (text !== "")
                text = "";
            else
                field.released();
        }

        // The view clears the query too (Enter, a click on the rail): typing breaks a
        // `text:` binding, so the field follows by hand
        Connections {
            target: field.view
            function onQueryChanged() {
                if (input.text !== field.view.query)
                    input.text = field.view.query;
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === "" && !input.preeditText
            text: "Search settings"
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
        }
    }

    // The key hint says what will happen: idle it says how to come here,
    // typing it says how to get out
    Rectangle {
        id: hint
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: hintText.implicitWidth + 16
        height: 24
        radius: 12
        color: Theme.withAlpha(Theme.surfaceText, 0.07)
        StyledText {
            id: hintText
            anchors.centerIn: parent
            text: field.typed ? "Esc clears" : field.view.compact ? "/" : "Ctrl+F or /"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }
}
