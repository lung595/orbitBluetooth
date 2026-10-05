import QtQuick
import QtQuick.Shapes
import qs.Common
import "Centre.js" as Centre
import "WiredSign.js" as Sign

// The cable from the source to a wired member of the group (D298): one thin
// straight line, the sound is copied from the source and the beams already run
// from it to every copy. It hangs loose when the output joins and goes taut in
// 0.4 s, once: the only animation here, none with Reduce motion (taut at once).
// Taut, it is a line like the Bluetooth beams' and costs the same: its ends
// follow the discs, which the scene's step moves. Drawn in the beams' layer,
// under every planet, and a little pulse travels along it only while sound plays.
Item {
    id: cable

    required property var centre
    // The output's node name (Member.js), from the row this cable is for
    required property string address

    readonly property var night: centre.scene.night
    readonly property var origin: centre.pointOf(centre.source)
    readonly property var end: centre.pointOf(address)
    // The source needs no cable to itself
    readonly property bool linked: address !== centre.source && !!origin && !!end
    readonly property real length: linked ? Math.hypot(end.x - origin.x, end.y - origin.y) : 0

    // How taut it is, from 0 (loose) to 1 (taut). Reduce motion: taut, always.
    property real pull: 0
    readonly property real tension: centre.scene.motion ? pull : 1
    readonly property real drop: Sign.drop(length, tension)
    readonly property var pulse: Centre.pulse(centre.beamTime, centre.copies.indexOf(address), centre.copies.length)
    readonly property var spark: linked ? Sign.along(origin, end, pulse.at, drop) : null

    // It tightens as the camera is about to land (so it is taut on arrival), or
    // at once when it joins a group that is already there, and again when it is
    // plugged into another source
    readonly property bool landing: centre.grouping >= 0.5
    function tighten() {
        if (!centre.scene.motion)
            return;
        pull = 0;
        tightening.restart();
    }
    onLandingChanged: if (landing)
        tighten()
    Component.onCompleted: if (landing)
        tighten()
    Connections {
        target: cable.centre
        function onSourceChanged() {
            if (cable.landing)
                cable.tighten();
        }
    }
    NumberAnimation {
        id: tightening
        target: cable
        property: "pull"
        to: 1
        duration: Sign.TIGHTEN
        easing.type: Easing.OutCubic
    }

    anchors.fill: parent
    visible: linked

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: line
            strokeColor: Theme.withAlpha(cable.night.primary, 0.5)
            strokeWidth: 1.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: cable.origin ? cable.origin.x : 0
            startY: cable.origin ? cable.origin.y : 0

            // The control point hangs under the middle while the cable is loose
            // and is on the line once it is taut
            PathQuad {
                x: cable.end ? cable.end.x : 0
                y: cable.end ? cable.end.y : 0
                controlX: (line.startX + x) / 2
                controlY: (line.startY + y) / 2 + cable.drop
            }
        }
    }

    Rectangle {
        visible: cable.centre.playing && !!cable.spark
        x: cable.spark ? cable.spark.x - width / 2 : 0
        y: cable.spark ? cable.spark.y - height / 2 : 0
        width: 6
        height: width
        radius: width / 2
        color: Theme.withAlpha(cable.night.primary, 0.9 * cable.pulse.alpha)
    }
}
