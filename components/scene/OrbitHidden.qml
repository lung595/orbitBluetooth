import QtQuick

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
        if (scene.focusBody === b)
            scene.clearFocus();
        if (b.phase === "connecting")
            scene.cancelConnect(b);
        b.swallow();
        scene.sounds.play("disconnect");
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
