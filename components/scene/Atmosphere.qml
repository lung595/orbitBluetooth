import QtQuick
import qs.Common

// A soft, static glow of the sky's own colour, elliptical and fading to
// nothing at its edge: the deep atmosphere a group stands in while the sky
// behind it is out of focus (Depth.js). One Vignette shape: it is drawn once,
// and only again when it is moved or resized (never animated), so it costs
// nothing at rest. Give it a size and a place; `strength` is its alpha.
Item {
    id: root
    required property NightColors night
    // The colour it glows with: the sky's own, tinted with the theme's accent
    property real tint: 0.1
    property real strength: 0
    // Over a smoky dark base (the glass veil) or the accent itself (the glow)
    property bool smoky: true

    visible: strength > 0.001

    Vignette {
        color: root.smoky ? Qt.tint(root.night.skyDeep, Theme.withAlpha(root.night.primary, root.tint)) : Theme.withAlpha(root.night.primary, 1)
        strength: root.strength
    }
}
