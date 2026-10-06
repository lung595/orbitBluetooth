import QtQuick
import "../scene/Physics.js" as Physics
import "../volume"
import "WiredSign.js" as Sign

// The mouse and the wheel over a wired member of the group, on the rounded
// square it is drawn with. A click opens the volume radar on its level, since
// there is no detail card for an output that is not Bluetooth (D271); a
// right-click opens its menu, and a drag past 5 px pulls it out of the group like
// a Bluetooth member (the scene owns the drag), so a group of wired outputs alone
// stays in hand and no gesture on it is met with silence (value 10). The wheel
// sets its level (over the source, the general one), as on any member.
MouseArea {
    id: pointer
    required property var body

    // At least the body, as the scene's own click search sees it
    // (Physics.hitDiameter): a member drawn small still has a usable zone
    anchors.centerIn: parent
    width: Physics.hitDiameter(pointer.body)
    height: width
    hoverEnabled: true
    preventStealing: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    enabled: !pointer.body.scene.cardOpen
    cursorShape: pointer.body.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    // The shape itself: the box's corners belong to what lies behind. The wheel
    // below is held to the same zone.
    containmentMask: QtObject {
        function contains(point: point): bool {
            return Sign.inside(point.x - pointer.width / 2, point.y - pointer.height / 2, pointer.width);
        }
    }

    property point pressPoint

    function worldPoint(m) {
        return mapToItem(pointer.body.scene.world, m.x, m.y);
    }

    onPressed: m => {
        pressPoint = worldPoint(m);
        if (m.button === Qt.RightButton)
            pointer.body.scene.openMenu(pointer.body, mapToItem(pointer.body.scene, m.x, m.y));
    }
    onPositionChanged: m => {
        if (!pressed || pressedButtons & Qt.RightButton)
            return;
        const p = worldPoint(m);
        if (!pointer.body.dragging && Math.hypot(p.x - pressPoint.x, p.y - pressPoint.y) > 5)
            pointer.body.scene.beginDrag(pointer.body, p);
        if (pointer.body.dragging)
            pointer.body.scene.updateDrag(p);
    }
    onReleased: m => {
        if (m.button === Qt.RightButton)
            return;
        if (pointer.body.dragging)
            pointer.body.scene.endDrag();
        else
            pointer.body.scene.focusOn(pointer.body);
    }
    onCanceled: if (pointer.body.dragging)
        pointer.body.scene.endDrag()
    onContainsMouseChanged: pointer.body.scene.wake()

    NotchWheel {
        onTurned: notches => pointer.body.centre.volume.turn(pointer.body.address, notches > 0 ? 1 : -1)
    }
}
