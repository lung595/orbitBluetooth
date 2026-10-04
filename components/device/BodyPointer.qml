import QtQuick
import "../scene/Physics.js" as Physics

// A device's mouse: a short click focuses it, a drag past 5 px moves it
// (the scene owns the drag), a right click opens its menu.
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
    enabled: !pointer.body.leaving && !pointer.body.swallowing && !pointer.body.scene.focusBody && !pointer.body.scene.hiddenOpen
    cursorShape: pointer.body.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    // The disc itself: the square's corners belong to what lies behind
    containmentMask: QtObject {
        function contains(point: point): bool {
            return Math.hypot(point.x - pointer.width / 2, point.y - pointer.height / 2) <= pointer.width / 2;
        }
    }

    property point pressPoint
    property double pressTime: 0

    function worldPoint(m) {
        return mapToItem(pointer.body.scene.world, m.x, m.y);
    }

    onPressed: m => {
        pressPoint = worldPoint(m);
        pressTime = Date.now();
        // Right click: the device menu (connect, noise control, hide)
        if (m.button === Qt.RightButton)
            pointer.body.scene.openMenu(body, mapToItem(pointer.body.scene, m.x, m.y));
    }
    onPositionChanged: m => {
        if (!pressed || pressedButtons & Qt.RightButton)
            return;
        const p = worldPoint(m);
        if (!pointer.body.dragging && Math.hypot(p.x - pressPoint.x, p.y - pressPoint.y) > 5)
            pointer.body.scene.beginDrag(body, p);
        if (pointer.body.dragging)
            pointer.body.scene.updateDrag(p);
    }
    onReleased: m => {
        if (m.button === Qt.RightButton)
            return;
        if (pointer.body.dragging)
            pointer.body.scene.endDrag();
        else if (Date.now() - pressTime < 450)
            pointer.body.scene.focusOn(body);
    }
    onCanceled: if (pointer.body.dragging)
        pointer.body.scene.endDrag()
    onContainsMouseChanged: pointer.body.scene.wake()
}
