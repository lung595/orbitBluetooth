import QtQuick
import qs.Common
import qs.Widgets

// Shown at the bottom of the sky, above the planets, when something you tried did not work: never a
// silent refusal (value 10). One line says what happened, a second what to
// do, and the GitHub mark opens the guide section that explains it. It goes
// away by itself; its timer only runs while a note is shown.
Rectangle {
    id: note

    required property var scene
    // { title, hint, anchor }: set by scene.explain(), null when gone
    readonly property var info: scene.note

    visible: opacity > 0.01
    opacity: info ? 1 : 0
    Behavior on opacity {
        enabled: note.scene.motion
        NumberAnimation {
            duration: 150
        }
    }
    anchors.horizontalCenter: parent.horizontalCenter
    // Bottom edge: never on top of a planet or its label
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 16
    z: 20000
    width: row.implicitWidth + 24
    height: row.implicitHeight + 14
    radius: height / 2
    color: scene.night.smoke(0.96)
    border.width: 1
    border.color: scene.night.ink(0.12)

    // Waits while it is pointed at, so the link can be reached
    Timer {
        running: !!note.info && !hover.hovered
        interval: 5000
        onTriggered: note.scene.note = null
    }
    HoverHandler {
        id: hover
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            StyledText {
                text: note.info ? note.info.title : ""
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: note.scene.night.ink(0.9)
            }
            StyledText {
                text: note.info ? note.info.hint : ""
                font.pixelSize: Theme.fontSizeSmall - 1
                color: note.scene.night.ink(0.6)
            }
        }
        GuideLink {
            anchors.verticalCenter: parent.verticalCenter
            anchor: note.info ? note.info.anchor : ""
            color: note.scene.night.ink(0.6)
            hoverColor: note.scene.night.primary
        }
    }
}
