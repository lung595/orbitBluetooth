import QtQuick
import qs.Common
import "../device"
import "../device/Glyphs.js" as Glyphs
import "Centre.js" as Centre
import "Perspective.js" as Perspective
import "WiredSign.js" as Sign

// A wired output listening together, drawn among the group's planets (D298): a
// rounded square where a Bluetooth device is a round disc, with the picture of
// its kind of connection (USB, HDMI, jack). The cable that links it to the
// source is drawn under the planets (WiredCable). It is not carried by physics:
// it sits where the group's own rule puts it (OrbitCentre.spotOf, the one that
// places the Bluetooth members too), so it needs no loop of its own and a
// settled scene costs it nothing. It answers what the scene asks of a body
// (where it is, how big, connected) so that a device dropped on it joins the
// group like on any other member.
Item {
    id: body

    required property var scene
    // The output's node name (Member.js): what a device's address is to a body
    required property string address

    readonly property var centre: scene.centre
    readonly property var night: scene.night

    // --- Where it is and what it is ----------------------------------------------
    readonly property string role: Centre.roleOf(centre.members, centre.source, address)
    readonly property var spot: centre.spotOf(address)
    // Carried by the pointer while it is dragged out of the group (OrbitDrag)
    readonly property real px: dragging ? scene.dragX : spot.x
    readonly property real py: dragging ? scene.dragY : spot.y
    readonly property real depth: spot.depth
    readonly property real diameter: spot.size
    readonly property var node: centre.session ? centre.session.memberNode(address) : null
    readonly property string kind: Sign.kindOf(address, node ? node.properties : null)
    readonly property string name: scene.together.nameOf(address)

    // --- What the scene's drag and drop ask of a body (OrbitDrag, OrbitTogether,
    // OrbitInvite): it is connected, drawn at its size, and never leaves or is
    // swallowed by itself
    readonly property bool wired: true
    readonly property bool connected: true
    readonly property bool leaving: false
    readonly property bool swallowing: false
    readonly property real baseScale: 1
    // The drag's state, as on a Bluetooth body: held by the group, so pulling
    // it away arms it to leave; never hidden into the black hole (an output
    // has no place in the hidden list)
    readonly property bool holding: true
    readonly property string phase: "connected"
    property bool dragging: false
    property bool armed: false
    property bool hideArmed: false
    readonly property alias pointer: mouse
    readonly property bool hovered: mouse.containsMouse && !scene.focusBody && !scene.hiddenOpen

    // It grows into its place and fades in when it joins or takes another role: a
    // brief transition, once, none with Reduce motion
    property real arrive: 0
    property real popScale: 1
    property real hoverScale: hovered ? 1.07 : 1
    Behavior on hoverScale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    function pop() {
        popAnim.restart();
    }
    function _arrive() {
        if (scene.motion) {
            arrive = 0;
            arriving.restart();
        } else {
            arriving.stop();
            arrive = 1;
        }
    }
    onRoleChanged: _arrive()
    Component.onCompleted: _arrive()

    NumberAnimation {
        id: arriving
        target: body
        property: "arrive"
        to: 1
        duration: 300
        easing.type: Easing.OutCubic
    }
    PopAnimation {
        id: popAnim
        body: body
    }

    width: diameter
    height: diameter
    x: px - width / 2
    y: py - height / 2
    // Among the group's planets: the source at the group's own order, a copy by its depth
    z: Centre.bodyZ(body, centre.grouped, centre.groupZ)
    opacity: centre.presence * scene.world.dim

    Item {
        id: visual
        anchors.fill: parent
        scale: (0.7 + 0.3 * body.arrive) * body.popScale * body.hoverScale
        // Darker on the far side of the orbit, as small as it is dark
        opacity: body.arrive * Perspective.haze(body.depth, body.centre.profile)

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.45
            height: width
            radius: width * Sign.CORNER
            color: Theme.withAlpha(body.night.primary, 0.07)
        }
        Rectangle {
            anchors.fill: parent
            radius: width * Sign.CORNER
            color: body.night.connectedFill
            border.width: 1
            border.color: body.night.connectedEdge
        }
        DeviceGlyph {
            anchors.centerIn: parent
            width: parent.width * 0.55
            height: width
            kind: Glyphs.wired(body.kind)
            color: body.night.connectedInk
            stroke: 1.5
        }

        // A copy's own level while the pointer is on it (CentreVolume)
        Loader {
            anchors.centerIn: parent
            active: body.role === "copy" && body.hovered
            sourceComponent: MemberLevel {
                body: body
            }
        }
    }

    WiredLabel {
        anchors.fill: parent
        body: body
    }
    WiredPointer {
        id: mouse
        body: body
    }
}
