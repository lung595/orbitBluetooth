import QtQuick
import qs.Common
import qs.Widgets
import "../common"

// Who is asking, on the planet: the device's name (renamed in place
// before connecting), what it is, and why it failed with a link to the
// guide. PairingSheet places it and fades it in.
Column {
    id: identity

    // The sheet (PairingSheet.qml): its phase, name and rename state
    required property var sheet
    // The sheet's colours (its `skin`)
    required property var look

    spacing: 2

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: identity.sheet.renaming ? identity.width - 48 : nameRow.implicitWidth
        height: nameRow.implicitHeight

        Row {
            id: nameRow
            visible: !identity.sheet.renaming
            spacing: 6
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: identity.sheet.name
                color: identity.look.ink(0.96)
                font.pixelSize: Theme.fontSizeLarge + 10
                font.weight: Font.Bold
                font.letterSpacing: -0.4
                // One line: a long name (an alias) is cut, never wrapped
                wrapMode: Text.NoWrap
                maximumLineCount: 1
                elide: Text.ElideRight
                width: Math.min(implicitWidth, identity.width - 76)
            }
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: identity.sheet.phase === "offer"
                name: "edit"
                size: 16
                color: identity.look.ink(0.4)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        nameInput.text = identity.sheet.name;
                        identity.sheet.renaming = true;
                        nameInput.forceActiveFocus();
                        nameInput.selectAll();
                    }
                }
            }
        }

        // Rename before connecting: Enter keeps it, Escape cancels
        Rectangle {
            visible: identity.sheet.renaming
            anchors.fill: parent
            anchors.margins: -4
            radius: 12
            color: identity.look.tileFill
            border.width: 1
            border.color: identity.look.accent
            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: identity.look.ink(0.96)
                selectionColor: Theme.withAlpha(identity.look.accent, 0.4)
                font.pixelSize: Theme.fontSizeLarge + 6
                font.weight: Font.Bold
                maximumLength: 40
                clip: true
                // Leaving the field keeps what was typed: Enter, a click
                // elsewhere on the sheet, or another window taking the
                // keyboard. Only Escape gives the old name back.
                property bool hadFocus: false
                function commit() {
                    if (!identity.sheet.renaming)
                        return;
                    identity.sheet.renaming = false;
                    hadFocus = false;
                    identity.sheet.renamed(text.trim());
                    identity.sheet.forceActiveFocus();
                }
                onActiveFocusChanged: {
                    if (activeFocus)
                        hadFocus = true;
                    else if (hadFocus)
                        commit();
                }
                Keys.onReturnPressed: commit()
                Keys.onEnterPressed: commit()
                Keys.onEscapePressed: {
                    hadFocus = false;
                    identity.sheet.renaming = false;
                    identity.sheet.forceActiveFocus();
                }
            }
        }
    }
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: identity.sheet.phase === "failed" ? identity.sheet.errorText : identity.sheet.phase === "confirm" ? "It can also send key presses, often for its buttons. Only continue if it is yours." : identity.sheet.renaming ? "Enter or click away to keep · Escape to cancel" : identity.sheet.subtitle
        color: identity.sheet.phase === "failed" ? Theme.error : identity.sheet.phase === "confirm" ? identity.look.ink(0.78) : identity.look.ink(0.5)
        width: Math.min(implicitWidth, identity.sheet.width - 48)
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Theme.fontSizeSmall
        font.letterSpacing: 0.2
    }
    // Why it failed, explained in the guide (value 10)
    GuideLink {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: identity.sheet.phase === "failed"
        anchor: identity.sheet.errorAnchor
        color: identity.look.ink(0.5)
        hoverColor: identity.look.accent
    }
}
