import QtQuick

// A device's mouse: a short click focuses it, a drag past 5 px moves it
// (the scene owns the drag), a right click opens its menu.
MouseArea {
    id: pointer
    required property var body

    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    enabled: !pointer.body.leaving && !pointer.body.swallowing && !pointer.body.scene.focusBody && !pointer.body.scene.hiddenOpen
    cursorShape: pointer.body.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

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
