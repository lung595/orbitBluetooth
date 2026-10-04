import QtQuick
import qs.Widgets
import "Centre.js" as Centre
import "../device"

// The name of the group under the centre, "XM6 + Marantz": the source first,
// then the copies in the order they joined. It sits below the copies' orbit,
// so a copy passing in front never covers it (and above every planet).
Item {
    id: caption

    required property var centre
    readonly property var night: centre.scene.night
    readonly property string text: Centre.label([centre.source].concat(centre.copies).map(a => centre.scene.together.nameOf(a)))

    // Centred under the group, but never cut off by the scene's edge (the
    // group steps back to a corner)
    x: Math.max(name.width / 2 + 8, Math.min(centre.scene.width - name.width / 2 - 8, centre.group.x))
    y: centre.group.y + Centre.labelOffset(centre.sizes) * centre.group.scale
    opacity: centre.presence

    LabelGlow {
        x: name.x + name.width / 2 - width / 2
        y: name.y + name.height / 2 - height / 2
        spanX: name.width + 30
        spanY: name.height + 14
        color: caption.night.primary
        strength: 0.2
    }

    StyledText {
        id: name
        x: -width / 2
        width: Math.min(implicitWidth, caption.centre.scene.width * 0.8)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: caption.text
        color: caption.night.ink(0.9)
        font.pixelSize: Math.max(10, Math.round(caption.centre.scene.coreSize * 0.2))
        font.weight: Font.Medium
    }
}
