import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "../device"
import "../volume"
import "Radar.js" as Radar

// One dial of the volume radar: a gauge of 270° that opens at the bottom, with
// the picture of what it is and its level in its middle, its name under it, and a
// speaker badge in the opening that mutes it. The hero is drawn big, a satellite
// small; both answer the same gestures: a drag on the ring sets the level, the
// wheel steps it, the badge mutes, and a tap on the middle of a satellite asks
// to make it the hero. Static art: it paints when its level moves, nothing here
// runs by itself.
Item {
    id: dial

    // { id, name, icon (a Material symbol) or glyph (a device glyph), level 0..1, muted, ready, color }
    required property var info
    required property var night
    property bool hero: false
    property real radius: 40

    signal moved(real level)
    signal stepped(int dir)
    signal muteClicked
    signal picked

    width: radius * 2
    height: width

    readonly property real stroke: Math.max(hero ? 6 : 3, radius * (hero ? 0.09 : 0.12))
    readonly property real arcRadius: radius - stroke / 2 - 1
    readonly property bool dim: info.muted || !info.ready
    readonly property color tint: dim ? night.ink(0.38) : info.color
    // The thumb at the end of the level arc, where a drag would take it
    readonly property real thumbAngle: Radar.angleOf(info.level) * Math.PI / 180

    // What the dial stands on
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - dial.stroke * 2 - 2
        height: width
        radius: width / 2
        color: Theme.withAlpha(dial.info.color, dial.hero ? 0.1 : 0.14)
        border.width: area.containsMouse && !dial.hero ? 1 : 0
        border.color: Theme.withAlpha(dial.info.color, 0.7)
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.withAlpha(dial.info.color, 0.2)
            strokeWidth: dial.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: dial.radius
                centerY: dial.radius
                radiusX: dial.arcRadius
                radiusY: dial.arcRadius
                startAngle: Radar.START
                sweepAngle: Radar.SWEEP
            }
        }
        ShapePath {
            strokeColor: dial.tint
            strokeWidth: dial.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: dial.radius
                centerY: dial.radius
                radiusX: dial.arcRadius
                radiusY: dial.arcRadius
                startAngle: Radar.START
                sweepAngle: Radar.SWEEP * Math.max(0.004, dial.info.ready ? dial.info.level : 0)
            }
        }
    }
    Rectangle {
        visible: dial.info.ready
        width: dial.stroke + 4
        height: width
        radius: width / 2
        x: dial.radius + Math.cos(dial.thumbAngle) * dial.arcRadius - width / 2
        y: dial.radius + Math.sin(dial.thumbAngle) * dial.arcRadius - height / 2
        color: dial.night.ink(0.95)
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -dial.radius * 0.04
        spacing: dial.radius * 0.05
        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!dial.info.icon
            name: dial.info.icon ?? ""
            size: Math.round(dial.radius * 0.46)
            color: dial.night.ink(dial.dim ? 0.5 : 0.95)
        }
        DeviceGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !dial.info.icon
            width: Math.round(dial.radius * 0.46)
            height: width
            kind: dial.info.glyph ?? ""
            color: dial.night.ink(dial.dim ? 0.5 : 0.95)
            stroke: 1.6
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.info.ready ? Radar.percent(dial.info.level) + "%" : "–"
            color: dial.night.ink(dial.dim ? 0.55 : 0.95)
            font.pixelSize: Math.round(dial.radius * (dial.hero ? 0.32 : 0.3))
            font.weight: Font.DemiBold
        }
    }

    // Its name, under the dial
    StyledText {
        y: dial.height + (dial.hero ? 8 : 1)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(72, dial.radius * 3)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: dial.info.name
        color: dial.night.ink(dial.hero ? 0.95 : 0.7)
        font.pixelSize: dial.hero ? 14 : 10
        font.weight: dial.hero ? Font.DemiBold : Font.Normal
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: dial.hero ? Qt.ArrowCursor : Qt.PointingHandCursor
        // The ring is for the level, the middle for a tap
        property bool turning: false
        function onRing(m) {
            return Math.hypot(m.x - dial.radius, m.y - dial.radius) > dial.radius * 0.6;
        }
        function levelAt(m) {
            return Radar.levelAt(m.x - dial.radius, m.y - dial.radius);
        }
        onPressed: m => {
            turning = onRing(m);
            if (turning)
                dial.moved(levelAt(m));
        }
        onPositionChanged: m => {
            if (turning)
                dial.moved(levelAt(m));
        }
        onReleased: {
            if (!turning && !dial.hero)
                dial.picked();
            turning = false;
        }
        onCanceled: turning = false
    }
    NotchWheel {
        onTurned: notches => dial.stepped(notches > 0 ? 1 : -1)
    }

    // The speaker in the gauge's opening: mutes this one, or lets it speak again
    Rectangle {
        id: badge
        width: dial.hero ? 28 : 18
        height: width
        radius: width / 2
        x: dial.radius - width / 2
        y: dial.radius + dial.arcRadius * 0.74 - height / 2
        color: dial.info.muted ? dial.night.ink(0.16) : Theme.withAlpha(dial.info.color, 0.92)
        DankIcon {
            anchors.centerIn: parent
            name: dial.info.muted ? "volume_off" : "volume_up"
            size: Math.round(parent.width * 0.62)
            color: dial.info.muted ? dial.night.ink(0.85) : dial.night.smoke(1)
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            enabled: dial.info.ready
            cursorShape: Qt.PointingHandCursor
            onClicked: dial.muteClicked()
        }
    }
}
