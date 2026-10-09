import QtQuick
import qs.Common
import "../common/Guide.js" as Guide
import "../device/DeviceCatalog.js" as Catalog

// The volumes of the listening group at the centre (D284): the general level
// (GroupVolume) as the ring and the wheel use it, and each copy's own level.
GroupVolume {
    id: volume

    required property var scene

    // The wheel over a member: the source moves the general level, a copy its
    // own, and a copy with none says why instead of staying silent (value 10)
    function turn(address, dir) {
        if (address === session.source) {
            step(dir);
            return;
        }
        const node = ownNode(address);
        if (node) {
            SessionData.suppressOSDTemporarily();
            route.touch(address);
            route.stepNode(node, dir);
        } else if (!scene.note || scene.note.anchor !== "the-volume-at-the-center")
            scene.explain(Guide.copyLevelNote(Catalog.deviceName(scene.deviceMap[address]) || session.nameOf(address)));
    }
}
