import QtQuick

// A small dot on the device the volume keys move while it is not the output
// you hear (NAK-196, D379): the keys follow the last level that changed, and
// without it the user could not tell why a device that is not playing moves.
// Static: no timer, no animation; the Loader that holds it exists only while
// the mark shows. The root fills the disc (a Loader resizes what it loads),
// the dot sits in its corner.
Item {
    id: mark

    required property var body

    Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: mark.width * 0.06
        width: Math.max(6, mark.width * 0.16)
        height: width
        radius: width / 2
        color: mark.body.night.primary
        // A thin sky-coloured rim keeps the dot readable on a pale disc
        border.width: 1.5
        border.color: mark.body.night.sky
    }
}
