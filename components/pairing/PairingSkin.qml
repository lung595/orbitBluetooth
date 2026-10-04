import QtQuick
import qs.Common
import "../common/Palette.js" as Palette

// The pairing sheet's colours, for one of its two skins:
// - Dark, "deep space": blue-black sky, a dark planet, accents lifted to glow.
// - Light, "stratosphere": pearly sky and porcelain planet, accents deepened
//   to read on the pearl, ink in a deep shade of the accent's hue.
// The DMS palette only enters through the accent, which each skin moves to a
// readable contrast (Palette.js), so any palette works on either skin.
QtObject {
    id: skin

    // Follows DMS; the preview can force it
    required property bool light
    // The device picture's colour (PictureColor.qml), transparent when unknown
    required property color picked

    function rgb(o) {
        return Qt.rgba(o.r, o.g, o.b, 1);
    }

    // A grey theme accent borrows the picture's colour when there is one
    readonly property color seed: Palette.isGrey(Theme.primary) && picked.a > 0 ? picked : Theme.primary
    readonly property color seed2: Palette.isGrey(Theme.tertiary) ? seed : Theme.tertiary
    readonly property real hue: Palette.toHsl(seed).h

    // Sky, top to horizon
    readonly property color skyTop: light ? Qt.tint("#FFFFFF", Theme.withAlpha(seed, 0.07)) : Qt.tint("#04050A", Theme.withAlpha(seed, 0.05))
    readonly property color skyLow: light ? Qt.tint("#F1F2F7", Theme.withAlpha(seed, 0.12)) : Qt.tint("#0A0C14", Theme.withAlpha(seed, 0.08))
    // Planet, limb to the bottom of the card
    readonly property color planetTop: light ? Qt.tint("#E6E8EF", Theme.withAlpha(seed, 0.1)) : Qt.tint("#0E1119", Theme.withAlpha(seed, 0.12))
    readonly property color planetLow: light ? Qt.tint("#F7F8FB", Theme.withAlpha(seed, 0.03)) : "#06070B"

    // Accents: lifted to glow on the night, deepened to read on the pearl
    readonly property color accent: light ? rgb(Palette.ensureContrast(seed, planetTop, 4.5)) : rgb(Palette.ensureContrast(Palette.lift(seed, 0.66), skyLow, 6))
    readonly property color accent2: light ? rgb(Palette.ensureContrast(seed2, planetTop, 3)) : rgb(Palette.ensureContrast(Palette.lift(seed2, 0.6), skyLow, 4))
    // The device's own colour (picture) leads the light when known
    readonly property color glow: picked.a > 0 ? (light ? rgb(Palette.ensureContrast(picked, planetTop, 3)) : rgb(Palette.ensureContrast(Palette.lift(picked, 0.6), skyLow, 4))) : accent
    readonly property color inkOnAccent: rgb(Palette.onColor(accent))
    // Light itself (aurora, atmosphere, glows): on the pearl a dark accent
    // would look like smoke, so the light is a bright, saturated pastel
    readonly property color haze: light ? rgb(Palette.fromHsl(Palette.toHsl(glow).h, Math.max(Palette.toHsl(glow).s, 0.55), 0.68)) : glow

    // Ink: white on the night, a deep shade of the accent's hue on the pearl
    readonly property color inkBase: light ? rgb(Palette.fromHsl(hue, 0.22, 0.1)) : "#FFFFFF"
    function ink(a) {
        return Theme.withAlpha(inkBase, a);
    }
    readonly property color tileFill: light ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(1, 1, 1, 0.05)
    readonly property color tileBorder: ink(light ? 0.07 : 0.08)
}
