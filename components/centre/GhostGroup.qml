import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "../device"
import "../scene"
import "../scene/Hold.js" as Hold
import "../scene/Physics.js" as Physics
import "Centre.js" as Centre

// The ghost group, drawn (D298): a dotted, translucent planet on the host's
// ring, as big and where the group would be, with the names it would put
// together under it and a small cross. A click makes it a group, a right click,
// a press held 500 ms or the cross turns it down; OrbitGhost decides and answers. The dotted ring
// is painted once, at the group's size on the nearest point, and the ring's
// drift only carries and scales it (nothing is painted again). Nothing here
// animates: its coming and going is OrbitGhost's presence, stepped by the
// scene's own loop, and with Reduce motion it is simply there or not.
Item {
    id: view

    required property var ghost
    readonly property var scene: ghost.scene
    readonly property var night: scene.night

    // Answers the pointer only while the proposal stands and nothing else has the
    // scene's attention (a card, the hidden list, a device carried)
    readonly property bool live: ghost.offered && !scene.cardOpen && !scene.dragBody
    readonly property bool hovered: pick.containsMouse || badgeArea.containsMouse
    // Its drawn radius on its slot
    readonly property real edge: ghost.diameter / 2
    // The click zones, for the tests
    readonly property alias pointer: pick
    readonly property alias cross: badgeArea

    anchors.fill: parent
    // Not before the physics step has put it on its slot
    visible: ghost.placed

    Item {
        id: planet
        width: view.ghost.baseDiameter
        height: width
        x: view.ghost.px - width / 2
        y: view.ghost.py - height / 2
        // Grows a little as it comes, on top of the slot's size
        scale: view.ghost.depthScale * (0.9 + 0.1 * Centre.ease(view.ghost.presence))
        // As faint as it is far, and lit when the pointer is on it
        opacity: view.ghost.presence * view.ghost.haze * (view.hovered ? 1 : 0.8)

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.withAlpha(view.night.primary, view.hovered ? 0.16 : 0.07)
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.withAlpha(view.night.primary, 0.85)
                strokeWidth: 1.5
                strokeStyle: ShapePath.DashLine
                dashPattern: [1.5, 3]
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc {
                    centerX: planet.width / 2
                    centerY: centerX
                    radiusX: centerX - 1
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 359.9
                }
            }
        }
        DankIcon {
            anchors.centerIn: parent
            name: "speaker_group"
            size: parent.width * 0.5
            color: view.night.ink(0.9)
        }
    }

    // Who it would put together, in icons, the output in use first (the names and
    // what a click does are said once the pointer is on it). Under the planet, or
    // above it on the far side of the ring (as a device's: the core is behind it
    // there), and never cut off by the scene's edge.
    GroupGlyphs {
        id: glyphs
        readonly property bool far: view.ghost.py < view.scene.centre.host.y
        scene: view.scene
        session: view.ghost.session
        members: view.ghost.proposal ? view.ghost.proposal.members : []
        // As big as the planet is
        disc: Centre.glyphDisc(view.scene.coreSize, view.ghost.diameter / view.scene.coreSize)
        named: view.hovered
        note: "Listen together"
        above: far
        x: Math.max(8, Math.min(view.scene.width - width - 8, view.ghost.px - width / 2))
        y: far ? view.ghost.py - view.edge - 5 - height : view.ghost.py + view.edge + 5
        opacity: view.ghost.presence * (view.hovered ? 1 : 0.85)
    }

    // A click makes it a group, a right click or a press held 500 ms (D368) turns
    // it down. The zone is the disc, and never smaller than a planet's (Physics.HIT_MIN): far away on the
    // ring it is as easy to click as a near one.
    MouseArea {
        id: pick
        width: Math.max(Physics.HIT_MIN, view.ghost.diameter)
        height: width
        x: view.ghost.px - width / 2
        y: view.ghost.py - height / 2
        enabled: view.live
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        containmentMask: QtObject {
            function contains(point: point): bool {
                return Math.hypot(point.x - pick.width / 2, point.y - pick.height / 2) <= pick.width / 2;
            }
        }
        // Set by the release that ends a long press, read by the click it is followed by
        property bool spent: false
        property point pressAt

        HoldRing {
            id: hold
            night: view.night
            onHeld: view.ghost.decline()
        }
        onEnabledChanged: if (!enabled)
            hold.cancel()
        onPressed: m => {
            pressAt = Qt.point(m.x, m.y);
            spent = false;
            if (m.button === Qt.LeftButton)
                hold.begin();
        }
        onPositionChanged: m => {
            // Hover moves arrive without a press, and a fired hold must stay fired
            if (!pressed || hold.fired)
                return;
            if (Hold.moved(pressAt, Qt.point(m.x, m.y)))
                hold.cancel();
        }
        onReleased: {
            spent = hold.fired;
            hold.cancel();
        }
        onCanceled: hold.cancel()
        onClicked: m => {
            if (spent)
                return;
            m.button === Qt.RightButton ? view.ghost.decline() : view.ghost.accept();
        }
    }

    // The cross: not this group again until the shell ends
    Rectangle {
        id: badge
        readonly property real span: Math.max(16, Math.round(view.ghost.diameter * 0.34))
        // On the upper right of the disc's click zone, mostly outside it: far away on the
        // ring the planet is hardly bigger than the cross, and a click in the middle of
        // the planet must never land on it
        readonly property real reach: (pick.width / 2 + span * 0.3) * Math.SQRT1_2
        width: span
        height: span
        radius: span / 2
        x: view.ghost.px + reach - width / 2
        y: view.ghost.py - reach - height / 2
        color: badgeArea.containsMouse ? view.night.error : Qt.rgba(0.1, 0.1, 0.12, 0.95)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
        opacity: view.ghost.presence * (view.hovered ? 1 : 0.55)

        DankIcon {
            anchors.centerIn: parent
            name: "close"
            size: parent.width * 0.7
            color: badgeArea.containsMouse ? view.night.errorText : Qt.rgba(1, 1, 1, 0.8)
        }
        MouseArea {
            id: badgeArea
            anchors.fill: parent
            anchors.margins: -3
            enabled: view.live
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: view.ghost.decline()
        }
    }
}
