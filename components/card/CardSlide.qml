import QtQuick
import qs.Common

// The rise every card of the scene shares: it rests on the bottom edge, centred,
// slides up (480 ms OutCubic) while it fades in (300 ms), and goes back down the
// same way. The detail card, the hidden list and the volume radar all sit in
// one, so they move alike and the rule lives here only. The size is the host's
// to give; what it holds is its child.
Item {
    id: slide

    required property var scene
    property bool shown: false

    x: (scene.width - width) / 2
    y: shown ? scene.height - height - Theme.spacingM : scene.height + 20
    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on y {
        NumberAnimation {
            duration: 480
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 300
        }
    }
}
