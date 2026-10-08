import QtQuick

// A body's one-shot motions: the focus grow and shrink, the pop, the shake, the
// swallow into the black hole and the tether pulse. Each one writes a value
// DeviceBody declares (focusScale, popScale, shakeX, swallowScale) and its
// bindings multiply; nothing here runs between two motions.
Item {
    id: motion

    required property var body
    required property Item visual       // turned by the swallow
    required property Item tether       // thickened by the pulse

    function pop() {
        popAnim.restart();
    }
    function shake() {
        shakeAnim.restart();
    }
    function swallow() {
        swallowAnim.restart();
    }
    function pulseTether() {
        tetherPulse.restart();
    }

    // Focus mode: the glyph flies to the card and grows, breaking out of its
    // frame. Driven by explicit animations (not a Behavior) so leaving focus
    // always lands back on exactly 1.
    Connections {
        target: motion.body
        function onFocusedChanged() {
            focusGrow.stop();
            focusShrink.stop();
            (motion.body.focused ? focusGrow : focusShrink).restart();
        }
    }
    SequentialAnimation {
        id: focusGrow
        PauseAnimation {
            duration: 140
        }
        NumberAnimation {
            target: motion.body
            property: "focusScale"
            to: motion.body.scene.focusGlyphScale
            duration: 520
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }
    }
    NumberAnimation {
        id: focusShrink
        target: motion.body
        property: "focusScale"
        to: 1
        duration: 340
        easing.type: Easing.OutCubic
    }
    Connections {
        target: motion.body.scene
        enabled: motion.body.focused
        function onFocusGlyphScaleChanged() {
            if (!focusGrow.running)
                motion.body.focusScale = motion.body.scene.focusGlyphScale;
        }
    }

    // Spirals into the black hole, then the scene hides it for good
    ParallelAnimation {
        id: swallowAnim
        readonly property int duration: motion.body.scene.motion ? 560 : 200
        NumberAnimation {
            target: motion.body
            property: "swallowScale"
            to: 0
            duration: swallowAnim.duration
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: motion.visual
            property: "rotation"
            to: motion.body.scene.motion ? 420 : 0
            duration: swallowAnim.duration
            easing.type: Easing.InCubic
        }
        onFinished: motion.body.scene.finishHide(motion.body)
    }

    PopAnimation {
        id: popAnim
        body: motion.body
    }

    SequentialAnimation {
        id: shakeAnim
        loops: 1
        NumberAnimation {
            target: motion.body
            property: "shakeX"
            to: -6
            duration: 50
        }
        NumberAnimation {
            target: motion.body
            property: "shakeX"
            to: 5
            duration: 70
        }
        NumberAnimation {
            target: motion.body
            property: "shakeX"
            to: -3
            duration: 70
        }
        NumberAnimation {
            target: motion.body
            property: "shakeX"
            to: 0
            duration: 90
        }
    }

    // The tether thickens as a connection lands
    SequentialAnimation {
        id: tetherPulse
        NumberAnimation {
            target: motion.tether
            property: "thickness"
            to: 3.2
            duration: 160
        }
        NumberAnimation {
            target: motion.tether
            property: "thickness"
            to: 1.5
            duration: 600
            easing.type: Easing.OutCubic
        }
    }
}
