import QtQuick
import "MemberColors.js" as MemberColors

// The colors of the outputs listening together and of this PC's level
// (MemberColors.js), as QML colors: one per output, left to right, then
// this PC's. One place for the scope and the strip, so a member is the same
// color in both
QtObject {
    // How many outputs share the sound (0 or 1: the device alone)
    required property int count
    // The theme's accents: [primary, secondary, tertiary]
    required property var bases

    readonly property var colors: MemberColors.pick(bases, count).map(c => Qt.rgba(c.r, c.g, c.b, 1))
    readonly property color pc: colors[colors.length - 1]
}
