import QtQuick
import "Physics.js" as Physics

// The drag gestures of the scene: a body is picked up, armed when it enters
// the magnet's reach (or the black hole's), and what it was armed for
// happens when it is let go (connect, disconnect, cancel or hide). A
// connected audio device let go over another one listens together with it
// (togetherDrop, OrbitTogether); pulled out of the group it leaves it. The state (dragBody, dragX, dragY,
// holeFeed, togetherDrop) stays on the scene, where the bodies and the
// world read it.
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
        const arm = Physics.dragArm(scene.centre.geometryOf(b), b.holding, p.x, p.y);
        b.hideArmed = arm.hide;
        scene.holeFeed = arm.feed;
        b.armed = arm.armed;
        if ((b.armed && !wasArmed && !b.holding) || (b.hideArmed && !wasHide)) {
            b.pop();
            scene.sounds.play("snap");
        }
        _overDevice(b, p);
        scene.wake();
    }

    // The connected device under the pointer, while neither the black hole
    // nor the tear point has the drop. A device that is not connected yet is
    // taken to the group at the centre too, to be told to connect it first.
    function _overDevice(b, p) {
        let target = null;
        if ((b.connected ? !b.armed : scene.centre.wanted) && !b.hideArmed) {
            const o = Physics.dropOnto(b, scene.world.bodyList(), p.x, p.y, scene.centre.wanted);
            target = scene.together.relevant(b, o) ? o : null;
        }
        if (target === scene.togetherDrop)
            return;
        scene.togetherDrop = target;
        if (target && scene.together.ready(b, target)) {
            target.pop();
            scene.sounds.play("snap");
        }
    }

    function end() {
        const b = scene.dragBody;
        scene.dragBody = null;
        if (!b)
            return;
        b.dragging = false;
        scene.holeFeed = 0;
        const mate = scene.togetherDrop;
        scene.togetherDrop = null;
        if (mate && !b.hideArmed) {
            scene.together.drop(b, mate);
        } else if (b.hideArmed) {
            b.hideArmed = false;
            scene.hideBody(b);
        } else if (b.armed) {
            // Pulled out of a group, a device leaves it and stays connected
            if (scene.together.isMember(b.address))
                scene.together.leave(b.address);
            else if (b.connected)
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
