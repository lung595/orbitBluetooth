import QtQuick
import qs.Common

// Colors for everything drawn as a card over the sky: the detail card, the
// hidden list, the right-click menu, their tiles, noise-control panel and
// earbuds trio. Dark theme: smoked glass with light ink (unchanged). Light
// theme: a soft off-white (never pure white) with dark blue-grey ink; the
// theme's own accents read well on it, so cards use them as they are.
QtObject {
    readonly property bool light: Theme.isLightMode

    readonly property color ink: light ? "#1D242D" : "#F2F5EE"
    // Ink with transparency: secondary text, hairlines, subtle fills
    function fg(a) {
        return light ? Qt.rgba(0.11, 0.14, 0.19, a) : Qt.rgba(1, 1, 1, a);
    }
    // Card glass
    function fill(a) {
        return light ? Qt.rgba(0.925, 0.937, 0.953, Math.min(1, a + 0.08)) : Qt.rgba(0.075, 0.08, 0.095, a);
    }
    // The battery ramp is tuned for dark glass; deepened on paper
    function level(c) {
        return light ? Qt.darker(c, 1.5) : c;
    }
}
