import QtQuick
import QtQuick.Effects

// A blurred and darkened copy of `source`, rendered ONCE into a texture and
// kept: between two retakes it is a plain textured quad, no effect redraws
// (the blur passes sit inside a layer that is never live). The source is read
// only while a retake is scheduled, so it holds no reference to it (and the
// scene can stop drawing it) the rest of the time.
//
// Retakes: when the copy is created, and a moment after the size, the blur
// radius or `token` change (the source's look changed). `ready` is true once
// the copy shows what the source looked like.
Item {
    id: root
    required property Item source
    // Blur radius in px and share darkened toward black (0..1), at full strength:
    // the fade in and out is the opacity of this item, never a re-blur
    property real radius: 24
    property real dim: 0.45
    // Any change of this value means the source looks different: retake
    property var token: null
    readonly property bool ready: _done

    property bool _done: false
    property bool _reading: false

    function retake() {
        _done = false;
        _reading = true;
        // The source texture, then the blur chain, then the kept copy, in one frame
        grab.scheduleUpdate();
        kept.scheduleUpdate();
    }

    // A burst of changes (a window being resized) makes one retake, after it
    function _soon() {
        settle.restart();
    }
    onWidthChanged: _soon()
    onHeightChanged: _soon()
    onRadiusChanged: _soon()
    onTokenChanged: _soon()
    Component.onCompleted: retake()

    Timer {
        id: settle
        interval: 150
        onTriggered: root.retake()
    }

    ShaderEffectSource {
        id: grab
        sourceItem: root._reading ? root.source : null
        live: false
        hideSource: false
        visible: false
    }

    MultiEffect {
        id: blurred
        anchors.fill: parent
        source: grab
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: root.radius
        // Toward black, not a brightness offset: the sky is already dark, an
        // offset would crush its faint stars and nebulae to nothing
        colorization: root.dim
        colorizationColor: "black"
    }

    ShaderEffectSource {
        id: kept
        anchors.fill: parent
        sourceItem: blurred
        live: false
        hideSource: true
        onScheduledUpdateCompleted: {
            root._reading = false;
            root._done = true;
        }
    }
}
