import QtQuick

// The detail card's focus and the rename of a device from it, and the
// Escape key that steps back one level. The state (focusBody, renaming)
// stays on the scene, where the bodies and the cards read it.
Item {
    id: focusCtl
    required property var scene
    // The right-click menu, closed first by Escape
    required property var menu

    function on(b) {
        if (!b || b.leaving)
            return;
        // The listening group stepped back to give the centre to the host: a
        // click on it takes the centre back
        if (scene.centre.recalled && scene.centre.holds(b)) {
            scene.centre.release();
            return;
        }
        scene.focusBody = b;
        scene.wake();
        scene.forceActiveFocus();
    }

    function clear() {
        scene.renaming = false;
        if (!scene.focusBody)
            return;
        scene.focusBody = null;
        scene.wake();
    }

    // A click on the empty sky steps back one level: the detail card or the
    // hidden list that is open, then Fedora's view while a group has the centre
    function stepBack() {
        if (scene.focusBody || scene.hiddenOpen) {
            clear();
            scene.closeHidden();
            return;
        }
        scene.centre.recall();
    }

    // The new name is the BlueZ alias: shown everywhere on the system, kept
    // by BlueZ itself (Orbit stores nothing). An empty name gives the device
    // its own name back.
    function rename(b, text) {
        scene.renaming = false;
        if (!b || !b.device)
            return;
        const next = text.trim();
        if (next === b.name)
            return;
        b.device.name = next;
    }

    // Escape steps back one level (rename, menu, hidden list, detail card)
    // before it may close the host. A Shortcut runs before the host's own
    // key handler (the bar popout and Control Center keep keyboard focus for
    // themselves), and it is only enabled while there is something to step
    // back from.
    Shortcut {
        sequence: "Escape"
        enabled: focusCtl.scene.active && (focusCtl.scene.menuOpen || focusCtl.scene.hiddenOpen || !!focusCtl.scene.focusBody)
        onActivated: {
            if (focusCtl.scene.renaming)
                focusCtl.scene.renaming = false;
            else if (focusCtl.scene.menuOpen)
                focusCtl.menu.close();
            else if (focusCtl.scene.hiddenOpen)
                focusCtl.scene.closeHidden();
            else
                focusCtl.clear();
        }
    }
}
