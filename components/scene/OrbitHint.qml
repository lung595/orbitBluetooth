import QtQuick
import qs.Common
import qs.Widgets

// The contextual hint under the orbit: what releasing a dragged device will
// do, or how to find devices when there are none.
StyledText {
    id: hint
    required property var scene
    required property int bodyCount   // device bodies in the orbit

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: hint.scene.glass ? Math.round(hint.scene.height * 0.1) : Theme.spacingS
    opacity: hint.scene.focusBody || hint.scene.hiddenOpen ? 0 : hint.text ? 0.6 : 0
    color: "white"
    font.pixelSize: Theme.fontSizeSmall - 1
    font.letterSpacing: 0.4
    text: {
        const b = hint.scene.dragBody;
        if (b && b.hideArmed)
            return "Release to hide";
        if (b && hint.scene.togetherDrop)
            return hint.scene.together.hint(b, hint.scene.togetherDrop);
        if (b) {
            if (b.phase === "connecting")
                return b.armed ? "Release to cancel" : "Pull away to cancel";
            if (b.connected)
                return b.armed ? "Release to disconnect" : "Pull away to disconnect";
            return b.armed ? "Release to connect" : "Bring it closer to connect";
        }
        if (!hint.scene.btOn)
            return "";
        if (hint.bodyCount === 0)
            return hint.scene.discovering ? "Looking for devices..." : "Tap the center to scan";
        return "";
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 200
        }
    }
}
