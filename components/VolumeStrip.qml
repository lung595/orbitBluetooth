import QtQuick
import qs.Common
import qs.Widgets

// The card's two volumes folded into one thin line (bar pop-out and Control
// Center, where the full scope would make the settings scroll): each level
// as a slim bar with its icon and percentage. A click unfolds the scope;
// the wheel steps the level under the pointer, as on the scope. Nothing
// runs here: it only shows the levels it is given.
Rectangle {
    id: strip

    // CardVolume: the levels to show
    required property var levels
    signal unfold
    // A wheel notch over a level: +1 up, -1 down (the card's smart steps)
    signal stepped(string part, int dir)

    readonly property bool hovered: area.containsMouse
    // The card's surface colors, light or dark, like its stat tiles
    readonly property PaperColors paper: PaperColors {}
    readonly property color muted: paper.fg(0.42)
    implicitHeight: 32
    radius: height / 2
    color: paper.fg(hovered ? 0.08 : 0.045)
    border.width: 1
    border.color: paper.fg(0.05)

    // One level: icon, slim bar, percentage
    component Level: Row {
        property string icon: ""
        property real level: 0
        property bool muted: false
        property color tint: Theme.primary
        property real barWidth: 40
        spacing: Theme.spacingXS
        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: parent.muted ? "volume_off" : parent.icon
            size: 16
            color: parent.muted ? strip.muted : parent.tint
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.barWidth
            height: 4
            radius: 2
            color: Theme.withAlpha(parent.tint, 0.18)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.parent.level))
                height: parent.height
                radius: parent.radius
                color: parent.parent.muted ? strip.muted : parent.parent.tint
            }
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            text: parent.muted ? "Muted" : Math.round(parent.level * 100) + "%"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            font.features: {
                "tnum": 1
            }
            color: parent.muted ? strip.muted : parent.tint
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        spacing: Theme.spacingM
        // Room for the bars once icons, numbers, gaps and the chevron are set
        readonly property real barWidth: Math.max(24, (strip.width - Theme.spacingM * 3 - 24 - (strip.levels.deviceLevel >= 0 ? 2 : 1) * (16 + 34 + Theme.spacingXS * 2) - (strip.levels.deviceLevel >= 0 ? Theme.spacingM : 0)) / (strip.levels.deviceLevel >= 0 ? 2 : 1))

        Level {
            id: deviceRow
            visible: strip.levels.deviceLevel >= 0
            icon: strip.levels.deviceIcon
            level: Math.max(0, strip.levels.deviceLevel)
            muted: strip.levels.deviceMuted
            tint: Theme.primary
            barWidth: row.barWidth
        }
        Level {
            id: pcRow
            icon: strip.levels.pcIcon
            level: strip.levels.pcLevel
            muted: strip.levels.pcMuted
            tint: Theme.tertiary
            barWidth: row.barWidth
        }
    }

    DankIcon {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        name: "expand_more"
        size: 20
        color: strip.hovered ? strip.paper.ink : strip.muted
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: strip.unfold()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real acc: 0
        onWheel: e => {
            // The level under the pointer: the device's on the left half
            // of the line when it has one, this PC's everywhere else
            const part = deviceRow.visible && e.x < row.x + pcRow.x - row.spacing / 2 ? "device" : "pc";
            // Touchpads send small deltas: add them up to whole notches
            acc += e.angleDelta.y;
            const notches = Math.trunc(acc / 120);
            if (notches === 0)
                return;
            acc -= notches * 120;
            for (let k = 0; k < Math.abs(notches); k++)
                strip.stepped(part, notches > 0 ? 1 : -1);
        }
    }
}
