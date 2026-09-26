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
    readonly property color tertiary: night(Theme.tertiary)
    readonly property color error: night(Theme.error)
    readonly property color primaryText: onAccent(Theme.primary, Theme.primaryText)
    readonly property color errorText: onAccent(Theme.error, Theme.errorText)
}
