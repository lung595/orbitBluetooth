import QtQuick
import "../volume"

// The wheel over a member of a Listen together group (OrbitCentre): over the
// source it moves the general level, over a copy that copy's own level, and a
// copy with none says why. The round disc only, which is bigger than the
// body's item when the source takes the centre.
Item {
    id: wheel
    required property var body

    anchors.centerIn: parent
    width: parent.width * Math.max(1, wheel.body.baseScale)
    height: width
    enabled: wheel.body.role !== ""
    containmentMask: QtObject {
        function contains(point: point): bool {
            return Math.hypot(point.x - wheel.width / 2, point.y - wheel.height / 2) <= wheel.width / 2;
        }
    }

    NotchWheel {
        onTurned: notches => wheel.body.scene.centre.volume.turn(wheel.body.address, notches > 0 ? 1 : -1)
    }
}
