import QtQuick
import QtQuick.Shapes
import "Centre.js" as Centre

// The copies' trajectory (D349): a light dashed ellipse around the group, like
// the rings of this computer's system, on the very path every copy follows
// (Centre.copySlot). It says where a copy will go and that it passes behind the
// source. One half per instance: OrbitWorld puts the far half behind the source
// and the near half in front of it, under every copy. Laid out once at the
// group's full size and only carried and scaled with the group (as the ghost
// group's dotted ring is): nothing is painted or animated again.
Item {
    id: orbit

    required property var centre
    // Which half: the near one (the lower, in front of the source) or the far one
    required property bool near

    readonly property var night: centre.scene.night
    // The ellipse the copies' centres travel on, at the group's full size
    readonly property real radiusX: centre.sizes.radius
    readonly property real radiusY: radiusX * Centre.TILT
    readonly property real weight: 1

    // The ellipse, its stroke and its arc, for the tests
    readonly property alias ellipse: ellipse
    readonly property alias trail: trail
    readonly property alias arc: arc

    anchors.fill: parent
    opacity: centre.presence

    Shape {
        id: ellipse
        // Carried and scaled with the group, which is where the copies orbit
        x: orbit.centre.group.x - width / 2
        y: orbit.centre.group.y - height / 2
        width: (orbit.radiusX + orbit.weight) * 2
        height: (orbit.radiusY + orbit.weight) * 2
        scale: orbit.centre.group.scale
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: trail
            // Paler on the far side, as what is far is
            strokeColor: orbit.night.ink(orbit.near ? 0.18 : 0.11)
            strokeWidth: orbit.weight
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 5]
            fillColor: "transparent"
            PathAngleArc {
                id: arc
                centerX: orbit.radiusX + orbit.weight
                centerY: orbit.radiusY + orbit.weight
                radiusX: orbit.radiusX
                radiusY: orbit.radiusY
                startAngle: orbit.near ? 0 : 180
                sweepAngle: 180
            }
        }
    }
}
