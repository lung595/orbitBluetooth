import QtQuick

// A copy's own level as a thin arc around it, shown while the pointer is on
// it (the wheel sets it). Nothing is drawn for a device that has no level of
// its own: it follows the group's.
LevelArc {
    id: arc

    required property var body
    readonly property real own: body.scene.centre.volume.ownLevel(body.address)

    visible: own >= 0
    // Outside the noise-control halo and the battery arc
    radius: body.diameter / 2 + 12
    lineWidth: 2
    level: own
    trackColor: Qt.rgba(1, 1, 1, 0.12)
    levelColor: body.night.primary
}
