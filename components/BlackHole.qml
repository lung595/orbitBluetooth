import QtQuick
import qs.Common
import qs.Widgets

// The "Hidden" planet: a small black hole parked in a corner of the scene.
// Devices dragged into it disappear from the orbit (they stay connected);
// clicking it lists them so they can be brought back.
//
// The look is one fragment shader (shaders/blackhole.frag) that lenses the
// starfield behind it. Cost: the sky patch is re-sampled only when the stars
// change, and the tesseract only turns while the scene is awake, so a still
// scene renders nothing.
Item {
    id: hole

    required property var scene
    // The starfield item to bend (a sibling below this one)
    required property Item sky
    property int count: 0
    // 0 .. 1: how close a dragged device is (the hole "feeds" on it)
    property real feed: 0
    property real spin: 0

    readonly property real horizon: Math.round(scene.bodySize * 0.2)
    readonly property real lensRadius: horizon * 3
    readonly property bool hovered: area.containsMouse

    signal clicked

    width: lensRadius * 2
    height: width

    // Sky patch under the hole, re-rendered only when the stars change
    ShaderEffectSource {
        id: patch
        sourceItem: hole.sky
        sourceRect: Qt.rect(hole.x - hole.sky.x, hole.y - hole.sky.y, hole.width, hole.height)
        textureSize: Qt.size(Math.ceil(hole.width), Math.ceil(hole.height))
        live: !hole.scene.glass
        hideSource: false
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        readonly property var source: patch
        readonly property real sizePx: hole.width
        property real horizon: hole.horizon * (hole.hovered ? 1.06 : 1) * (1 + 0.12 * hole.feed)
        readonly property real strength: 1 + 0.45 * hole.feed + (hole.hovered ? 0.1 : 0)
        readonly property real spin: hole.spin
        readonly property color rimA: Theme.primary
        readonly property color rimB: Theme.tertiary
        // Lensing needs an opaque sky to redraw; the desktop's sky is
        // see-through (redrawing it would leave a grey disc), so it is off there
        readonly property real lens: hole.scene.glass ? 0 : 1
        readonly property color backdrop: "#06070b"
        fragmentShader: Qt.resolvedUrl("../shaders/blackhole.frag.qsb")

        Behavior on horizon {
            enabled: hole.scene.motion
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    // Name + how many devices it holds
    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 + hole.horizon + 6
        text: hole.count > 0 ? "Hidden · " + hole.count : "Hidden"
        color: Qt.rgba(1, 1, 1, hole.hovered || hole.feed > 0.3 ? 0.8 : 0.42)
        font.pixelSize: Math.max(9, Math.round(hole.scene.bodySize * 0.2))
        font.letterSpacing: 0.4
        visible: hole.scene.prefs.showLabels || hole.hovered || hole.feed > 0
        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
    }

    MouseArea {
        id: area
        anchors.centerIn: parent
        // Comfortable target even though the hole itself is tiny
        width: Math.max(hole.horizon * 2.6, hole.scene.bodySize * 0.8)
        height: width
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: hole.clicked()
        onContainsMouseChanged: hole.scene.wake()
    }
}
