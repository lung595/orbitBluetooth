import QtQuick
import qs.Widgets
import "../device"

// The name of a wired member while the pointer is on it. The group's name under
// the centre lists everyone; this says which disc is which, like the name a
// Bluetooth member shows on hover. Above the disc in the upper half of the
// group, under it elsewhere, so it never lands on the source.
Item {
    id: caption
    required property var body

    visible: caption.body.hovered

    LabelGlow {
        x: name.x + name.width / 2 - width / 2
        y: name.y + name.height / 2 - height / 2
        spanX: name.width + 30
        spanY: name.height + 14
        color: caption.body.night.primary
        strength: 0.26
    }

    StyledText {
        id: name
        readonly property bool above: caption.body.py < caption.body.centre.group.y
        readonly property real gap: caption.body.diameter / 2 + 5
        anchors.horizontalCenter: parent.horizontalCenter
        y: above ? caption.body.height / 2 - gap - height : caption.body.height / 2 + gap
        width: Math.min(implicitWidth, caption.body.diameter * 2.1)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: caption.body.name
        color: caption.body.night.ink(0.95)
        font.pixelSize: Math.max(9, Math.round(caption.body.diameter * 0.2))
        font.weight: Font.Medium
    }
}
