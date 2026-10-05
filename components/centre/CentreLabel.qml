import QtQuick
import "Centre.js" as Centre

// What the group is, under it: the icons of its members (GroupGlyphs), the
// source first and then the copies in the order they joined, never a name.
// They sit below the volume ring and the copies' orbit, so a copy passing in
// front never covers them (and above every planet). On the far side of the
// host's ring, in Fedora's view, they go above the group instead: the host's
// core is in front of what lies under it there, and the icons never land on it.
Item {
    id: caption

    required property var centre
    readonly property var scene: centre.scene

    // The group is on the far side of the host's ring: the icons go over it. The
    // switch glides (a short transition, none with Reduce motion), and nothing
    // else here moves by itself.
    readonly property bool above: centre.group.depth < 0
    property real flip: above ? 1 : 0
    Behavior on flip {
        NumberAnimation {
            duration: caption.scene.motion ? 200 : 0
            easing.type: Easing.OutCubic
        }
    }
    // How far from the group's middle the row starts, under it and over it: with
    // the group's size, as the ring does
    readonly property real under: Centre.glyphsOffset(centre.sizes, false) * centre.group.scale
    readonly property real over: Centre.glyphsOffset(centre.sizes, true) * centre.group.scale

    // Centred under the group, but never cut off by the scene's edge (the
    // group steps back to a corner)
    x: Math.max(glyphs.width / 2 + 8, Math.min(scene.width - glyphs.width / 2 - 8, centre.group.x))
    y: centre.group.y + under + flip * (-over - glyphs.height - under)
    opacity: centre.presence

    GroupGlyphs {
        id: glyphs
        x: -width / 2
        scene: caption.scene
        session: caption.centre.session
        members: [caption.centre.source].concat(caption.centre.copies)
        disc: Centre.glyphDisc(caption.scene.coreSize, caption.centre.group.scale)
        named: hover.hovered
        above: caption.above

        // Only to say the names: the pointer is never taken from what lies under
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
        // A tap opens the volume radar on the group's level
        TapHandler {
            onTapped: caption.scene.radar.show("")
        }
    }
}
