import QtQuick
import "../common/Guide.js" as Guide
import "../together/Choice.js" as Choice
import "Physics.js" as Physics

// Hiding a device in the black hole and getting it back. The device spirals
// into the hole; once it vanished it is saved as hidden (it stays
// connected, it just leaves the orbit). A device that comes back is spat
// out of the hole (the scene's spawnFrom). The state (hiddenOpen,
// spawnFrom, the hole's position) stays on the scene.
Item {
    id: hidden
    required property var scene

    function hide(b) {
        if (!b || b.swallowing || b.leaving)
            return;
        // A member would go on playing out of sight: it leaves the group first
        if (scene.together.isMember(b.address)) {
            scene.explain(Guide.togetherNote("in-group", scene.together.nameOf(b.address)));
            return;
        }
        if (scene.focusBody === b)
            scene.clearFocus();
        if (b.phase === "connecting")
            scene.cancelConnect(b);
        b.swallow();
        scene.sounds.play("disconnect");
        scene.wake();
    }

    // From the group chooser, an output by its id: a Bluetooth device on the sky
    // spirals into the hole like one dragged there; a wired output has no body,
    // the hole just takes it (it lights up for a moment). A member of the group
    // plays on, so it is not hidden: the note says why (value 10).
    function hideById(id, name) {
        const why = Choice.hideWhy(scene.together.members(), scene.prefs.hiddenDevices, id);
        if (why) {
            scene.explain(Guide.togetherNote(why, name, id));
            return;
        }
        const b = scene.world.bodyList().find(x => x.address === id);
        if (b) {
            hide(b);
            return;
        }
        scene.prefs.setHidden(id, name, true);
        scene.holeFlashAt = scene.fxTime;
        scene.sounds.play("disconnect");
        scene.wake();
    }

    // An output carried to the hole from a list, held at `point` (scene
    // coordinates): the hole feeds on it as on a dragged body and shows an eye.
    // True while it is over the hole, where letting go hides it.
    function carry(point) {
        const arm = Physics.dragArm(scene.centre.sunGeometry(), false, point.x, point.y);
        scene.holeFeed = arm.feed;
        scene.holeEye = true;
        scene.wake();
        return arm.hide;
    }

    function uncarry() {
        scene.holeFeed = 0;
        scene.holeEye = false;
        scene.wake();
    }

    function finish(b) {
        scene.prefs.setHidden(b.address, b.name, true);
        scene.refresh();
    }

    function unhide(address) {
        const next = Object.assign({}, scene.spawnFrom);
        next[address] = Qt.point(scene.holeX, scene.holeY);
        scene.spawnFrom = next;
        scene.prefs.setHidden(address, "", false);
        if (scene.hiddenCount <= 1)
            close();
        scene.wake();
    }

    function unhideAll() {
        const next = Object.assign({}, scene.spawnFrom);
        for (const a in scene.prefs.hiddenDevices)
            next[a] = Qt.point(scene.holeX, scene.holeY);
        scene.spawnFrom = next;
        scene.prefs.set("hiddenDevices", ({}));
        close();
        scene.wake();
    }

    function open() {
        scene.clearFocus();
        scene.hiddenOpen = true;
        scene.wake();
        scene.forceActiveFocus();
    }

    function close() {
        if (!scene.hiddenOpen)
            return;
        scene.hiddenOpen = false;
        scene.wake();
    }
}
