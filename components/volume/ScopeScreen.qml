import QtQuick
import qs.Common
import qs.Widgets
import "../card"
import "../common"
import "../scene"

// The vectorscope on its own screen (D262, D263), as the volume pop-up and
// the Dank Island sheet both show it: DMS's themed frame around it is the
// caller's, Orbit's screen is inside. Dark theme: a night screen with
// additive light, like a lit phosphor. Light theme: soft paper with the
// theme's own accents drawn over it (light added to paper would vanish).
// Nothing here runs unless `live`.
Item {
    id: screenItem

    // VolumeOverlay: the levels to show, what to do with a gesture
    required property var overlay
    property bool live: false
    // The unfolded facts are for the visit they were asked in: a pop-up
    // (and the island sheet, which keeps this item) opens folded every time
    onLiveChanged: if (!live)
        facts.expanded = false
    // Drawn lying flat, turned upright on a side (Route.popupLayout)
    property bool upright: false
    property real turn: 0
    // The frame's own corners (top-left, top-right, bottom-left,
    // bottom-right): the screen's corners run parallel to them
    property var radii: [Theme.cornerRadius, Theme.cornerRadius, Theme.cornerRadius, Theme.cornerRadius]
    readonly property real margin: Theme.spacingS
    // The note under the screen instead of over its foot (the detail card,
    // where it would hide the arcs); the item grows by noteRoom to hold it
    property bool noteBelow: false
    readonly property real noteRoom: noteBelow && note && !upright ? notePill.height + Theme.spacingXS : 0

    // A gesture: the caller keeps itself open a while longer
    signal touched
    readonly property bool hovered: scope.hovered

    readonly property NightColors night: NightColors {}
    readonly property PaperColors paper: PaperColors {}
    readonly property bool light: Theme.isLightMode
    // One color per output listening together, then this PC's: never twins
    // (MemberPalette). Alone, the device keeps the primary
    readonly property MemberPalette tones: MemberPalette {
        count: screenItem.overlay.members.length
        bases: screenItem.light ? [Theme.primary, Theme.secondary, Theme.tertiary] : [screenItem.night.primary, screenItem.night.secondary, screenItem.night.tertiary]
    }
    readonly property color deviceColor: tones.colors[0]
    readonly property color pcColor: tones.pc
    // The glass behind the pills at the foot (the facts, the note)
    readonly property color pillFill: light ? Theme.withAlpha(paper.fill(0.92), 0.92) : Theme.withAlpha(night.sky, 0.86)
    readonly property color pillStroke: light ? paper.fg(0.12) : night.ink(0.12)
    function _inner(r) {
        return Math.max(0, (r || 0) - margin);
    }

    // Fills the picture from a made-up frame (previews)
    function simulate(frame, seconds) {
        scope.simulate(frame, seconds);
    }

    Rectangle {
        id: screen
        anchors.fill: parent
        anchors.margins: screenItem.margin
        anchors.bottomMargin: screenItem.margin + screenItem.noteRoom
        topLeftRadius: screenItem._inner(screenItem.radii[0])
        topRightRadius: screenItem._inner(screenItem.radii[1])
        bottomLeftRadius: screenItem._inner(screenItem.radii[2])
        bottomRightRadius: screenItem._inner(screenItem.radii[3])
        gradient: Gradient {
            GradientStop {
                position: 0
                color: screenItem.light ? Qt.tint(screenItem.paper.fill(0.92), Theme.withAlpha(Theme.tertiary, 0.04)) : Qt.tint(screenItem.night.sky, Theme.withAlpha(screenItem.night.tertiary, 0.05))
            }
            GradientStop {
                position: 1
                color: screenItem.light ? Qt.tint(Qt.darker(screenItem.paper.fill(0.92), 1.04), Theme.withAlpha(Theme.primary, 0.06)) : Qt.tint(screenItem.night.skyDeep, Theme.withAlpha(screenItem.night.primary, 0.06))
            }
        }
    }

    PolarScope {
        id: scope
        anchors.centerIn: screen
        width: (screenItem.upright ? screen.height : screen.width) - Theme.spacingXS * 2
        height: (screenItem.upright ? screen.width : screen.height) - Theme.spacingXS * 2
        rotation: screenItem.turn

        style: screenItem.overlay.style
        grid: true
        additive: !screenItem.light
        deviceColor: screenItem.deviceColor
        memberColors: screenItem.tones.colors
        pcColor: screenItem.pcColor
        trackColor: screenItem.light ? screenItem.paper.fg(0.16) : screenItem.night.ink(0.14)
        inkColor: screenItem.light ? screenItem.paper.ink : screenItem.night.ink(0.92)
        mutedColor: screenItem.light ? screenItem.paper.fg(0.42) : screenItem.night.ink(0.4)
        hollowColor: screenItem.light ? screenItem.paper.fill(0.92) : screenItem.night.sky

        deviceLevel: screenItem.overlay.deviceLevel
        pcLevel: screenItem.overlay.pcLevel
        deviceMuted: screenItem.overlay.deviceMuted
        pcMuted: screenItem.overlay.pcMuted
        members: screenItem.overlay.members
        deviceIcon: screenItem.overlay.deviceIcon
        pcIcon: screenItem.overlay.pcIcon
        picture: screenItem.overlay.picture || null
        live: screenItem.live
        motion: !screenItem.overlay.reduceMotion
        fps: screenItem.overlay.fps

        onMoved: (part, level) => {
            screenItem.overlay.setLevel(part, level);
            screenItem.touched();
        }
        smartWheel: true
        numbers: true
        deviceLabel: screenItem.overlay.deviceName || "Device"
        onStepped: (part, dir) => {
            screenItem.overlay.stepLevel(part, dir);
            screenItem.touched();
        }
        onMuteClicked: part => {
            screenItem.overlay.toggleMute(part);
            screenItem.touched();
        }
    }
    // A one-line note at the foot of the screen (the volume keys, D265; a
    // device with no level of its own, D249), with an optional word to
    // click and the guide's link. On the right, so the mute
    // icons on the left stay reachable; centered under it with noteBelow.
    readonly property var note: overlay.note || null

    // What the output is (D260), in a pill centered at the foot, under the
    // fan's hub, clear of the mute icons at the left and the readouts at
    // the right. Not on the card, which has its own line under the name,
    // and not while a note shows
    property bool showFacts: true
    FactsLine {
        id: facts
        visible: screenItem.showFacts && !screenItem.note && !screenItem.upright
        source: screenItem.overlay
        up: true
        width: implicitWidth
        height: implicitHeight
        anchors.horizontalCenter: screen.horizontalCenter
        anchors.bottom: screen.bottom
        anchors.bottomMargin: Theme.spacingXS
        ink: screenItem.light ? screenItem.paper.ink : screenItem.night.ink(0.95)
        muted: screenItem.light ? screenItem.paper.fg(0.6) : screenItem.night.ink(0.62)
        fill: screenItem.pillFill
        stroke: screenItem.pillStroke
        onTouched: screenItem.touched()
    }
    Rectangle {
        id: notePill
        visible: !!screenItem.note && !screenItem.upright
        anchors.right: screenItem.noteBelow ? undefined : screen.right
        anchors.rightMargin: Theme.spacingM
        anchors.bottom: screenItem.noteBelow ? undefined : screen.bottom
        anchors.bottomMargin: Theme.spacingXS
        anchors.top: screenItem.noteBelow ? screen.bottom : undefined
        anchors.topMargin: Theme.spacingXS
        anchors.horizontalCenter: screenItem.noteBelow ? screen.horizontalCenter : undefined
        height: noteRow.height + 4
        width: noteRow.width + Theme.spacingM * 2
        radius: height / 2
        color: screenItem.pillFill
        border.width: 1
        border.color: screenItem.pillStroke

        Row {
            id: noteRow
            anchors.centerIn: parent
            spacing: Theme.spacingS
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: screenItem.note ? screenItem.note.text : ""
                font.pixelSize: Theme.fontSizeSmall
                color: screenItem.light ? screenItem.paper.fg(0.7) : screenItem.night.ink(0.72)
            }
            StyledText {
                id: noteAction
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: screenItem.note ? screenItem.note.action : ""
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: noteArea.containsMouse ? (screenItem.light ? Theme.primary : screenItem.night.ink(1)) : (screenItem.light ? Theme.primary : screenItem.night.primary)
                MouseArea {
                    id: noteArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        screenItem.overlay.noteAction();
                        screenItem.touched();
                    }
                }
            }
            GuideLink {
                anchors.verticalCenter: parent.verticalCenter
                anchor: screenItem.note && screenItem.note.anchor ? screenItem.note.anchor : "volume-keys"
                size: 12
                color: screenItem.light ? screenItem.paper.fg(0.5) : screenItem.night.ink(0.5)
                hoverColor: screenItem.light ? screenItem.paper.ink : screenItem.night.ink(0.95)
            }
        }
    }
}
