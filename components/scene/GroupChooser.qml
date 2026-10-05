pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import "../card"
import "../together"
import "../together/Choice.js" as Choice

// The page of the right-click menu where a Listen together group is made
// (D298): a checklist of the outputs that can play together, the wired ones
// that are plugged in and the Bluetooth ones that are connected, with the
// device the menu was opened on already ticked. What is listed and what can be
// ticked is decided by Choice.js; this is display and wiring. It only exists
// while it is open (OrbitMenu's Loader), and so does the one pactl call that
// lists the wired outputs: closed, nothing of it runs (value 6).
// A click on a row that cannot be ticked says why and leaves the chooser open
// (value 10); Escape, or a click elsewhere, closes the whole menu.
Rectangle {
    id: chooser

    required property var scene
    required property PaperColors paper
    // The device the menu was opened on: it starts ticked
    required property string address
    // Where the menu was: the chooser opens there, kept inside the sky
    property point origin: Qt.point(0, 0)

    // The button was pressed with enough ticked: what to listen together with
    signal confirmed(var chosen)
    // Something cannot be done, for the scene to explain
    signal refused(string why, string who)

    // What is ticked, in the order it was; `view.chosen` is what really counts
    property var chosen: [address]
    // The row under the pointer or the arrow keys
    property string cursorId: ""
    // The cursor was moved by a key: the list scrolls to it
    property bool byKey: false

    readonly property var words: Choice.labels(scene.together.members())
    readonly property var view: Choice.build({
        "wired": watch.outputs,
        "bluetooth": bluetooth(),
        "members": scene.together.members(),
        "chosen": chosen,
        "refusal": who => scene.together.memberCheck(who)
    })
    readonly property var rows: [].concat(...view.sections.map(s => s.rows))
    readonly property var plan: Choice.outcome(scene.together.members(), view.chosen)
    // Nothing to make a group of, now that the wired outputs have been read
    readonly property bool empty: watch.ready && !view.enough

    // Room kept under the chooser for the note the scene says at the bottom
    // (OrbitNote), so that a refusal is read while the chooser stays open
    readonly property real bottomRoom: 80
    // The list scrolls rather than leave the sky, whatever is plugged in
    readonly property real maxList: Math.max(96, scene.height - bottomRoom - 120)

    // The devices on the sky, as Choice.build reads them
    function bluetooth() {
        return scene.world.bodyList().filter(b => !b.leaving && !b.swallowing).map(b => ({
                    "address": b.address,
                    "name": b.name,
                    "kind": b.kind
                }));
    }

    // A click on a row: it is ticked or unticked, or says why it cannot be
    function pick(row) {
        if (row.why)
            refused(row.why, row.id);
        else
            chosen = Choice.toggle(view.chosen, row.id);
    }
    // The button: the group, or why it is not one yet
    function confirm() {
        if (plan.why)
            refused(plan.why, "");
        else
            confirmed(view.chosen);
    }
    // The arrow keys move along the rows, never past the first or the last
    function step(by) {
        if (!rows.length)
            return;
        const at = rows.findIndex(r => r.id === cursorId);
        byKey = true;
        cursorId = rows[at < 0 ? (by > 0 ? 0 : rows.length - 1) : Math.max(0, Math.min(rows.length - 1, at + by))].id;
    }
    // Arrows move, Space ticks the row under the cursor, Enter is the button.
    // True when the key was for the chooser.
    function press(key) {
        if (key === Qt.Key_Up || key === Qt.Key_Down) {
            step(key === Qt.Key_Down ? 1 : -1);
        } else if (key === Qt.Key_Space) {
            const row = rows.find(r => r.id === cursorId);
            if (row)
                pick(row);
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            confirm();
        } else {
            return false;
        }
        return true;
    }
    // Scrolls the list just enough to see `line`, with a heading's height of room
    // above it so that the first row of a section shows its heading
    function reveal(line) {
        const top = line.mapToItem(list, 0, 0).y;
        scroller.contentY = Math.max(top + line.height - scroller.height, Math.min(scroller.contentY, Math.max(0, top - 24)));
    }

    // The wired outputs are read in a few tens of ms: the chooser is shown once
    // they are, so that their section does not push the Bluetooth rows down as it
    // opens. Should the reading be slow or fail, it is shown without them.
    property bool waited: false
    readonly property bool listed: watch.ready || waited

    width: 252
    height: col.implicitHeight + 10
    x: Math.max(8, Math.min(origin.x, scene.width - width - 8))
    y: Math.max(8, Math.min(origin.y, scene.height - height - bottomRoom))
    radius: 14
    color: paper.fill(0.95)
    border.width: 1
    border.color: paper.fg(0.08)
    transformOrigin: Item.TopLeft
    scale: listed ? 1 : 0.92
    opacity: listed ? 1 : 0
    Behavior on scale {
        enabled: chooser.scene.motion
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }
    focus: true
    Keys.onPressed: event => event.accepted = chooser.press(event.key)
    Component.onCompleted: forceActiveFocus()

    // Clicks that miss a row stay here: they must not reach the menu's own
    // catch-all, which closes it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    // The wired outputs plugged in right now, read once, as it opens
    WiredWatch {
        id: watch
        active: true
    }
    // The one wait there is, and only until the chooser is shown
    Timer {
        interval: 500
        running: !chooser.listed
        onTriggered: chooser.waited = true
    }

    Column {
        id: col
        x: 5
        y: 5
        width: parent.width - 10
        spacing: 4

        Item {
            width: col.width
            height: 34
            DankIcon {
                id: titleIcon
                x: 9
                anchors.verticalCenter: parent.verticalCenter
                name: "group_add"
                size: 16
                color: chooser.paper.fg(0.75)
            }
            StyledText {
                anchors.left: titleIcon.right
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: chooser.words.title
                color: chooser.paper.ink
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
            }
        }

        Flickable {
            id: scroller
            width: col.width
            height: Math.min(list.implicitHeight, chooser.maxList)
            contentHeight: list.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: list
                width: scroller.width

                // One heading per kind of output, only for those there are
                Repeater {
                    model: chooser.view.sections

                    Column {
                        id: section
                        required property var modelData
                        width: list.width

                        StyledText {
                            width: parent.width
                            height: 24
                            leftPadding: 10
                            verticalAlignment: Text.AlignVCenter
                            text: section.modelData.title
                            color: chooser.paper.fg(0.55)
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: Font.Medium
                        }
                        Repeater {
                            model: section.modelData.rows

                            GroupRow {
                                id: line
                                required property var modelData
                                width: section.width
                                row: modelData
                                paper: chooser.paper
                                current: modelData.id === chooser.cursorId
                                onHovered: {
                                    chooser.byKey = false;
                                    chooser.cursorId = modelData.id;
                                }
                                onClicked: chooser.pick(modelData)
                                onCurrentChanged: {
                                    if (current && chooser.byKey)
                                        chooser.reveal(line);
                                }
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: chooser.empty
            width: col.width
            leftPadding: 10
            rightPadding: 10
            bottomPadding: 8
            wrapMode: Text.WordWrap
            text: chooser.words.empty
            color: chooser.paper.fg(0.6)
            font.pixelSize: Theme.fontSizeSmall - 1
        }

        // Validates: dim while there is not enough ticked, and then it says so
        Rectangle {
            id: button
            readonly property bool ready: chooser.plan.why === ""
            visible: !chooser.empty
            width: col.width
            height: 34
            radius: 10
            color: !ready ? chooser.paper.fg(0.08) : area.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: chooser.words.action
                color: button.ready ? Theme.primaryText : chooser.paper.fg(0.5)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chooser.confirm()
            }
        }
    }

    // Where the part in view sits in a list cut short by a small sky: without
    // it, a cut that falls between two rows hides that there are more
    Rectangle {
        objectName: "scrollMark" // found by the tests
        visible: scroller.interactive
        x: col.x + col.width - width - 2
        y: col.y + scroller.y + 2 + (scroller.height - 4) * scroller.visibleArea.yPosition
        width: 3
        height: (scroller.height - 4) * scroller.visibleArea.heightRatio
        radius: width / 2
        color: chooser.paper.fg(0.3)
    }
}
