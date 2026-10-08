import QtQuick
import qs.Common
import qs.Widgets
import "../card"
import "Polar.js" as Polar

// The card's volumes folded into one thin line (bar pop-out and Control
// Center, where the full scope would make the settings scroll): each level
// as a slim bar with its icon and percentage (the percentage leaves when
// four or more outputs share the line: the scope has it). A click unfolds the scope;
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
    // The same colors as the scope's arcs (MemberPalette)
    readonly property MemberPalette tones: MemberPalette {
        count: strip.levels.members.length
        bases: [Theme.primary, Theme.secondary, Theme.tertiary]
    }
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
        property bool compact: false
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
            visible: !parent.compact
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
        // One level for each output listening together, else the device's own
        // when it has one, then this PC's
        readonly property int outputs: strip.levels.split ? strip.levels.members.length : strip.levels.deviceLevel >= 0 ? 1 : 0
        readonly property int count: outputs + 1
        readonly property bool compact: count > 3
        // Room for the bars once icons, numbers, gaps and the chevron are set
        readonly property real barWidth: Math.max(24, (strip.width - Theme.spacingM * 3 - 24 - count * (16 + (compact ? 0 : 34) + Theme.spacingXS * (compact ? 1 : 2)) - (count - 1) * Theme.spacingM) / count)

        Repeater {
            id: outputRows
            model: row.outputs
            Level {
                required property int index
                readonly property var out: strip.levels.split ? strip.levels.members[index] : null
                icon: out ? out.icon : strip.levels.deviceIcon
                level: out ? out.level : Math.max(0, strip.levels.deviceLevel)
                muted: out ? out.muted : strip.levels.deviceMuted
                tint: strip.tones.colors[index]
                barWidth: row.barWidth
                compact: row.compact
            }
        }
        Level {
            id: pcRow
            icon: strip.levels.pcIcon
            level: strip.levels.pcLevel
            muted: strip.levels.pcMuted
            tint: strip.tones.pc
            barWidth: row.barWidth
            compact: row.compact
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

    NotchWheel {
        onTurned: (notches, wheelX) => {
            // The level under the pointer, left to right: the outputs' (the
            // device's own when it is alone), this PC's last
            const x = wheelX - row.x;
            let part = "pc";
            if (x < pcRow.x - row.spacing / 2)
                for (let i = row.outputs - 1; i >= 0; i--)
                    if (x >= outputRows.itemAt(i).x - row.spacing / 2 || i === 0) {
                        part = Polar.partOf(i, row.outputs);
                        break;
                    }
            for (let k = 0; k < Math.abs(notches); k++)
                strip.stepped(part, notches > 0 ? 1 : -1);
        }
    }
}
