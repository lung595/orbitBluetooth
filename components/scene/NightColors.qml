import QtQuick
import qs.Common

// Orbit always shows a night sky, whatever the DMS theme. A light theme's
// accents are dark (made for light surfaces) and would fade into the black
// sky, so the scene uses these instead: the theme's own hue and saturation,
// lifted to a lightness that reads on the dark sky (like Material's
// "inverse primary"). With a dark theme they are the theme colors, unchanged.
QtObject {
    readonly property bool lift: Theme.isLightMode
    // Light theme: devices (and the host) are white discs on the night sky,
    // their glyphs in the theme's own (dark) accent
    readonly property bool whiteBodies: Theme.isLightMode
    readonly property color bodyInk: Theme.primary
    readonly property color bodyMuted: Qt.rgba(0.1, 0.12, 0.16, 0.78)

    // How far two colours' hues are, as a share of the colour wheel (0..0.5)
    function hueApart(a, b) {
        const d = Math.abs(a.hslHue - b.hslHue);
        return Math.min(d, 1 - d);
    }
    function night(c) {
        if (!lift)
            return c;
        return Qt.hsla(c.hslHue, c.hslSaturation, Math.max(c.hslLightness, 0.74), c.a);
    }
    // Text drawn on top of an accent fill (dark on a lifted accent)
    function onAccent(c, fallback) {
        return lift ? Qt.hsla(c.hslHue, c.hslSaturation, 0.14, 1) : fallback;
    }

    readonly property color primary: night(Theme.primary)
    readonly property color secondary: night(Theme.secondary)
    readonly property color tertiary: night(Theme.tertiary)
    readonly property color error: night(Theme.error)
    readonly property color success: night(Theme.success)
    readonly property color warning: night(Theme.warning)
    // A battery that charges has a colour of its own: not the primary blue (the
    // volume ring's), not a traffic light. The theme's `info` is a fixed blue;
    // when the theme's primary is that same blue (a generated theme often is),
    // its tertiary, the accent that Material You keeps apart from the primary
    readonly property color charging: night(hueApart(Theme.info, Theme.primary) < 0.08 ? Theme.tertiary : Theme.info)
    readonly property color primaryText: onAccent(Theme.primary, Theme.primaryText)
    readonly property color errorText: onAccent(Theme.error, Theme.errorText)

    // A connected device's disc, its border and its glyph: one definition for
    // the Bluetooth bodies and the wired members of a group, so that both kinds
    // read as one family
    readonly property color connectedFill: whiteBodies ? Qt.tint("#FFFFFF", Theme.withAlpha(Theme.primary, 0.1)) : Qt.tint(Qt.rgba(0.06, 0.07, 0.09, 0.92), Theme.withAlpha(primary, 0.16))
    readonly property color connectedEdge: Theme.withAlpha(primary, 0.55)
    readonly property color connectedInk: whiteBodies ? bodyInk : Qt.lighter(primary, 1.12)

    // The sky itself and the ink drawn on it. The sky is night in every theme
    // on purpose, so these are the one place its constants live; everything
    // else (sizes, radii, spacing) comes from Theme.
    readonly property color sky: "#07080c"
    readonly property color skyDeep: "#05060a"
    function ink(alpha) {
        return Qt.rgba(1, 1, 1, alpha);
    }
    // Smoky pill drawn over the wallpaper (desktop glass chips)
    function smoke(alpha) {
        return Qt.rgba(0.04, 0.045, 0.06, alpha);
    }
}
