import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "../card"
import "../device"
import "../volume"
import "Radar.js" as Radar

// One dial of the volume radar: a gauge of 270° that opens at the bottom, a glass
// disc under it, the picture of what it is and its level in the middle. The hero
// is drawn big, with a mute pill in the opening; a small dial is a disc with its
// name under it. Both answer the same gestures: a drag on the ring sets the
// level, the wheel steps it, the speaker mutes, and a tap on the middle of a
// small dial asks to make it the hero. Static art: what moves (the level that
// glides, the entrance, the mute ring) is handed in by the view's one clock, so
// nothing here runs by itself.
Item {
    id: dial

    // { id, name, icon (a Material symbol) or glyph (a device glyph), level 0..1, muted, ready, color }
    required property var info
    required property PaperColors paper
    property bool hero: false
    property real radius: 40
    // The level drawn (the view glides it toward info.level), the entrance of a
    // small dial (0..1) and the mute ring on its way (0..1, 1 when there is none)
    property real level: info.level
    property real pop: 1
    property real ripple: 1

    signal moved(real level)
    signal stepped(int dir)
    signal muteClicked
    signal picked

    width: radius * 2
    height: width
    opacity: pop
    scale: 0.82 + 0.18 * pop

    readonly property real stroke: Math.max(hero ? 7 : 3, radius * (hero ? 0.085 : 0.12))
    readonly property real arcRadius: radius - stroke / 2 - 1
    readonly property bool dim: info.muted || !info.ready
    readonly property color accent: paper.level(info.color)
    readonly property color tint: dim ? paper.fg(0.3) : accent
    // A readable ink on the accent
    readonly property color onAccent: accent.hslLightness > 0.55 ? "#101114" : "#FFFFFF"
    // The thumb at the end of the level arc, where a drag would take it
    readonly property real thumbAngle: Radar.angleOf(level) * Math.PI / 180
    readonly property bool hovered: area.containsMouse && !hero

    // The glass disc the gauge stands on
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - dial.stroke * 2 - 2
        height: width
        radius: width / 2
        color: dial.paper.fg(dial.hero ? 0.035 : 0.05)
        border.width: 1
        border.color: dial.hovered ? Theme.withAlpha(dial.accent, 0.75) : dial.paper.fg(0.06)
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // A soft halo under the hero's level
        ShapePath {
            strokeColor: Theme.withAlpha(dial.tint, dial.hero ? 0.16 : 0)
            strokeWidth: dial.stroke * 2.6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: dial.radius
                centerY: dial.radius
                radiusX: dial.arcRadius
                radiusY: dial.arcRadius
                startAngle: Radar.START
                sweepAngle: Radar.SWEEP * Math.max(0.004, dial.info.ready ? dial.level : 0)
            }
        }
        ShapePath {
            strokeColor: dial.paper.fg(0.09)
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
        // Tick marks along the gauge: one dashed hairline
        ShapePath {
            strokeColor: dial.hero ? dial.paper.fg(0.22) : "transparent"
            strokeWidth: 1.5
            strokeStyle: ShapePath.DashLine
            dashPattern: [0.5, 9]
            fillColor: "transparent"
            PathAngleArc {
                centerX: dial.radius
                centerY: dial.radius
                radiusX: dial.arcRadius - dial.stroke - 6
                radiusY: dial.arcRadius - dial.stroke - 6
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
                sweepAngle: Radar.SWEEP * Math.max(0.004, dial.info.ready ? dial.level : 0)
            }
        }
    }
    // The thumb, with a halo
    Rectangle {
        visible: dial.info.ready
        width: dial.stroke + 9
        height: width
        radius: width / 2
        x: dial.radius + Math.cos(dial.thumbAngle) * dial.arcRadius - width / 2
        y: dial.radius + Math.sin(dial.thumbAngle) * dial.arcRadius - height / 2
        color: Theme.withAlpha(dial.tint, 0.25)
        Rectangle {
            anchors.centerIn: parent
            width: dial.stroke + 3
            height: width
            radius: width / 2
            color: dial.paper.ink
        }
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -dial.radius * (dial.hero ? 0.1 : 0.04)
        spacing: dial.radius * 0.05
        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !!dial.info.icon
            name: dial.info.icon ?? ""
            size: Math.round(dial.radius * (dial.hero ? 0.4 : 0.44))
            color: dial.dim ? dial.paper.fg(0.5) : dial.paper.ink
        }
        DeviceGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !dial.info.icon
            width: Math.round(dial.radius * (dial.hero ? 0.4 : 0.44))
            height: width
            kind: dial.info.glyph ?? ""
            color: dial.dim ? dial.paper.fg(0.5) : dial.paper.ink
            stroke: 1.6
        }
        // The true level, never the glide's step in between
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.info.ready ? Radar.percent(dial.info.level) + "%" : "–"
            color: dial.dim ? dial.paper.fg(0.55) : dial.paper.ink
            font.pixelSize: Math.round(dial.radius * (dial.hero ? 0.34 : 0.3))
            font.weight: Font.DemiBold
        }
    }

    // The name of a small dial, under it (the hero's is the card's title)
    StyledText {
        visible: !dial.hero
        y: dial.height + 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(72, dial.radius * 3)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
        text: dial.info.name
        color: dial.paper.fg(dial.hovered ? 0.9 : 0.62)
        font.pixelSize: 11
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

    // The speaker in the gauge's opening: a pill on the hero, a small disc on a
    // small dial. It mutes this one, or lets it speak again
    Rectangle {
        id: badge
        readonly property color ink: dial.info.muted ? dial.paper.ink : dial.onAccent
        width: dial.hero ? badgeRow.implicitWidth + 22 : 18
        height: dial.hero ? 26 : 18
        radius: height / 2
        x: dial.radius - width / 2
        y: dial.radius + dial.arcRadius * 0.74 - height / 2
        color: dial.info.muted ? dial.paper.fg(0.14) : dial.accent
        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 5
            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: dial.info.muted ? "volume_off" : "volume_up"
                size: dial.hero ? 15 : 11
                color: badge.ink
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: dial.hero
                text: dial.info.muted ? "Muted" : "Mute"
                color: badge.ink
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            enabled: dial.info.ready
            cursorShape: Qt.PointingHandCursor
            onClicked: dial.muteClicked()
        }
    }
    // The ring that leaves the badge when it is pressed
    Rectangle {
        visible: dial.ripple < 1
        anchors.centerIn: badge
        width: badge.width + (dial.hero ? 56 : 30) * dial.ripple
        height: badge.height + (dial.hero ? 56 : 30) * dial.ripple
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: dial.accent
        opacity: 0.6 * (1 - dial.ripple)
    }
}
