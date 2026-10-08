import QtQuick

// Stands in for DMS's DankToggle offscreen: the switch's own size (a 52 by 30
// track) and state, and the signal a tap raises. A test taps it with `toggled()`.
Item {
    property bool checked: false

    signal toggled(bool isChecked)

    width: 52
    height: 30
}
