import QtQuick
import qs.Common

// The layout of the detail card (focus mode): a small glyph (~20% of the
// card width) peeking ~30% above the card's top edge, the rest sitting
// inside the frame. Pure measures: the scene exposes them to the world, the
// bodies, the physics and the hosts.
QtObject {
    id: layout
    required property var scene

    readonly property real cardWidth: Math.min(scene.width - Theme.spacingL * 2, 360)
    readonly property real glyphRatio: 0.2
    readonly property real glyphSize: Math.min(cardWidth * glyphRatio, scene.height * 0.26)
    readonly property real glyphScale: glyphSize / scene.bodySize
    readonly property real glyphLift: glyphSize * 0.2      // glyph center relative to card top
    readonly property real overlap: glyphLift + glyphSize * 0.5 + 8
    // The same at the glyph's width-bound size, which never depends on the scene's height
    readonly property real fullOverlap: cardWidth * glyphRatio * 0.7 + 8
    // Room above the card for the glyph, which breaks out of its top edge:
    // its center sits 0.2 glyph below the card top, so 0.3 glyph rises
    // above it, plus a margin. Less than this and the window cuts it.
    readonly property real headroom: headroomFor(glyphSize)
    // Scene height at which the open detail card (or the radar) fits without scrolling (0
    // when none is open): card content, glyph overlap and margins, with the
    // glyph at its width-bound size. It does not depend on the scene's own
    // height, so a host can grow to it without a binding loop.
    readonly property real fitHeight: {
        const glyph = cardWidth * glyphRatio;
        // The radar's card, once it is made (its own height asks for the same glyph overhang)
        if (scene.radar.open)
            return scene.world.radarCard.wanted + headroomFor(glyph) + Theme.spacingM;
        if (!scene.focusBody)
            return 0;
        const content = scene.world.focusCard.implicitHeight - overlap - Theme.spacingL;
        return content + fullOverlap + Theme.spacingL + headroomFor(glyph) + Theme.spacingM;
    }

    function headroomFor(glyph) {
        return glyph * 0.3 + Theme.spacingS;
    }
}
