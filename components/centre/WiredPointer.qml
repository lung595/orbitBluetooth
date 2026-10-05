import QtQuick
import "../scene/Physics.js" as Physics
import "../volume"
import "WiredSign.js" as Sign

// The mouse and the wheel over a wired member of the group, on the rounded
// square it is drawn with. A press opens its menu (leave, stop together): the
// one thing it can be asked, since there is no detail card for an output that
// is not Bluetooth (D271) and it can be neither hidden nor pulled out by hand,
// so no gesture on it is met with silence (value 10). The wheel sets its level
// (over the source, the general one), as on any member.
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
    enabled: !pointer.body.scene.focusBody && !pointer.body.scene.hiddenOpen
    cursorShape: Qt.PointingHandCursor
    // The shape itself: the box's corners belong to what lies behind. The wheel
    // below is held to the same zone.
    containmentMask: QtObject {
        function contains(point: point): bool {
            return Sign.inside(point.x - pointer.width / 2, point.y - pointer.height / 2, pointer.width);
        }
    }

    onPressed: m => pointer.body.scene.openMenu(pointer.body, mapToItem(pointer.body.scene, m.x, m.y))
    onContainsMouseChanged: pointer.body.scene.wake()

    NotchWheel {
        onTurned: notches => pointer.body.centre.volume.turn(pointer.body.address, notches > 0 ? 1 : -1)
    }
}
