import QtQuick
import "../scene/Physics.js" as Physics
import "../scene/Hold.js" as Hold
import "../scene"

// A device's mouse: a short click focuses it, a drag past 5 px moves it
// (the scene owns the drag), a right click or a press held 500 ms opens its
// menu.
MouseArea {
    id: pointer
    required property var body

    // At least the body, and the whole disc when it is bigger (the source of
    // a Listen together at the centre): a planet drawn small still has a zone
    // as large as the one a click is searched in (Physics.hitDiameter)
    anchors.centerIn: parent
    width: Physics.hitDiameter(pointer.body)
    height: width
    hoverEnabled: true
    preventStealing: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    enabled: !pointer.body.leaving && !pointer.body.swallowing && !pointer.body.scene.cardOpen
    cursorShape: pointer.body.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    // The disc itself: the square's corners belong to what lies behind
    containmentMask: QtObject {
        function contains(point: point): bool {
            return Math.hypot(point.x - pointer.width / 2, point.y - pointer.height / 2) <= pointer.width / 2;
        }
    }

    property point pressPoint
    property point menuPoint
    property double pressTime: 0

    HoldRing {
        id: hold
        night: pointer.body.scene.night
        onHeld: pointer.body.scene.openMenu(pointer.body, pointer.menuPoint)
    }
    // Carried off or covered by a card in the middle of a press: nothing is left to hold
    onEnabledChanged: if (!enabled)
        hold.cancel()

    function worldPoint(m) {
        return mapToItem(pointer.body.scene.world, m.x, m.y);
    }

    onPressed: m => {
        pressPoint = worldPoint(m);
        pressTime = Date.now();
        menuPoint = mapToItem(pointer.body.scene, m.x, m.y);
        // Right click: the device menu (connect, noise control, hide); the left
        // button held 500 ms does the same (D368), for a mouse without a right
        // button and for touch
        if (m.button === Qt.RightButton)
            pointer.body.scene.openMenu(body, menuPoint);
        else
            hold.begin();
    }
    onPositionChanged: m => {
        if (!pressed || pressedButtons & Qt.RightButton || hold.fired)
            return;
        const p = worldPoint(m);
        if (!pointer.body.dragging && Hold.moved(pressPoint, p)) {
            hold.cancel();
            pointer.body.scene.beginDrag(body, p);
        }
        if (pointer.body.dragging)
            pointer.body.scene.updateDrag(p);
    }
    onReleased: m => {
        if (m.button === Qt.RightButton)
            return;
        // The menu is open: the release of the press that opened it is no click.
        // settle() first, for a release past HOLD_MS the Timer has not seen yet
        hold.settle();
        const spent = hold.fired;
        hold.cancel();
        if (spent)
            return;
        if (pointer.body.dragging)
            pointer.body.scene.endDrag();
        // Released before the hold fired is a click, up to the very moment the
        // menu would open: one threshold (Hold.HOLD_MS), so no gap does nothing
        else if (!Hold.done(Date.now() - pressTime))
            pointer.body.scene.focusOn(body);
    }
    onCanceled: {
        hold.cancel();
        if (pointer.body.dragging)
            pointer.body.scene.endDrag();
    }
    onContainsMouseChanged: pointer.body.scene.wake()
}
