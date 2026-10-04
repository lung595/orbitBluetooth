import QtQuick
import "Physics.js" as Physics

// The drag gestures of the scene: a body is picked up, armed when it enters
// the magnet's reach (or the black hole's), and what it was armed for
// happens when it is let go (connect, disconnect, cancel or hide). The
// state (dragBody, dragX, dragY, holeFeed) stays on the scene, where the
// bodies and the world read it.
Item {
    id: drag
    required property var scene

    function begin(b, p) {
        scene.dragBody = b;
        b.dragging = true;
        b.armed = false;
        scene.dragX = p.x;
        scene.dragY = p.y;
        scene.wake();
    }

    function update(p) {
        scene.dragX = p.x;
        scene.dragY = p.y;
        const b = scene.dragBody;
        if (!b)
            return;
        const wasArmed = b.armed;
        const wasHide = b.hideArmed;
        const arm = Physics.dragArm(scene, b.holding, p.x, p.y);
        b.hideArmed = arm.hide;
        scene.holeFeed = arm.feed;
        b.armed = arm.armed;
        if ((b.armed && !wasArmed && !b.holding) || (b.hideArmed && !wasHide)) {
            b.pop();
            scene.sounds.play("snap");
        }
        scene.wake();
    }

    function end() {
        const b = scene.dragBody;
        scene.dragBody = null;
        if (!b)
            return;
        b.dragging = false;
        scene.holeFeed = 0;
        if (b.hideArmed) {
            b.hideArmed = false;
            scene.hideBody(b);
        } else if (b.armed) {
            if (b.connected)
                scene.startDisconnect(b);
            else if (b.phase === "connecting")
                scene.cancelConnect(b);
            else
                scene.startConnect(b);
        }
        b.armed = false;
        scene.wake();
    }
}
