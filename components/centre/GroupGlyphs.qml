import QtQuick
import qs.Widgets
import "../device"
import "../device/DeviceCatalog.js" as Catalog
import "../device/Glyphs.js" as Glyphs
import "../together/Together.js" as Together
import "../together/Member.js" as Member
import "Centre.js" as Centre
import "WiredSign.js" as Sign

// A group said in icons, never in words: one round disc per member, the first
// member first, each overlapping the next like the bar pill's stack, with the
// glyph the member wears everywhere else (a Bluetooth device's own, the picture
// of a wired output's connection). The full names are only in a small tip while
// `named` is set. It draws and answers nothing else: the callers (the group's
// CentreLabel, the ghost's GhostGroup) place it. Nothing here animates or runs.
Item {
    id: glyphs

    required property var scene
    // The daemon's TogetherSession, for what a wired output is plugged into
    required property var session
    // The members' tokens (Member.js), in the order they are drawn
    required property var members
    // The disc's diameter (Centre.glyphDisc)
    required property real disc
    // The tip with the names, shown while the pointer is on the group, and what a
    // click would do there (the ghost's)
    property bool named: false
    property string note: ""
    // The tip goes over the row, not under it (the row is above its group)
    property bool above: false

    readonly property var shown: members.slice(0, Together.MAX_MEMBERS)
    readonly property var night: scene.night

    width: row.width
    height: row.height

    // The glyph of a member: a device's own, as its body wears it (the user's
    // choice first), or the picture of a wired output's connection
    function glyphOf(token) {
        if (Member.isWired(token)) {
            const node = session ? session.memberNode(token) : null;
            return Glyphs.wired(Sign.kindOf(token, node ? node.properties : null));
        }
        return Catalog.resolve(scene.deviceMap[token], scene.prefs.glyphOverrides);
    }

    Row {
        id: row
        spacing: Centre.glyphSpacing(glyphs.disc)

        Repeater {
            model: glyphs.shown
            delegate: Rectangle {
                id: member
                required property string modelData

                width: glyphs.disc
                height: width
                radius: width / 2
                color: glyphs.night.connectedFill
                border.width: 1
                border.color: glyphs.night.connectedEdge

                DeviceGlyph {
                    anchors.centerIn: parent
                    width: parent.width * 0.64
                    height: width
                    kind: glyphs.glyphOf(member.modelData)
                    color: glyphs.night.connectedInk
                    stroke: 1.8
                }
            }
        }
    }

    // Made only while it is asked for: nothing waits at rest
    Loader {
        active: glyphs.named
        x: (row.width - width) / 2
        y: glyphs.above ? -height - 4 : row.height + 4
        sourceComponent: Rectangle {
            implicitWidth: lines.implicitWidth + 14
            implicitHeight: lines.implicitHeight + 8
            radius: 7
            color: glyphs.night.smoke(0.88)
            border.width: 1
            border.color: glyphs.night.ink(0.12)

            Column {
                id: lines
                anchors.centerIn: parent
                Repeater {
                    model: glyphs.shown
                    delegate: StyledText {
                        required property string modelData
                        width: Math.min(implicitWidth, glyphs.scene.width * 0.5)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: glyphs.scene.together.nameOf(modelData)
                        color: glyphs.night.ink(0.92)
                        font.pixelSize: Math.max(9, Math.round(glyphs.scene.coreSize * 0.17))
                        font.weight: Font.Medium
                    }
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: glyphs.note !== ""
                    text: glyphs.note
                    color: glyphs.night.primary
                    font.pixelSize: Math.max(8, Math.round(glyphs.scene.coreSize * 0.15))
                }
            }
        }
    }
}
