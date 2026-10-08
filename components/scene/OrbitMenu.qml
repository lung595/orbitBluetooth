pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import "../card"
import "../together/Choice.js" as Choice
import "MenuEntries.js" as Entries

// Right-click menu of an orbiting device: connect/disconnect, the headset's
// noise-control modes when it has them, "Create a group…" (or "Add to the
// group…") for a device outside the group that can play sound, "Remove from
// group" for a member (a wired one reads "Disconnect": it leaves and stays
// plugged in), "Hide" (into the black hole) and "Forget" (unpair), which asks
// for a second click. Which entries, in which order, is MenuEntries.js; adding
// a device to the group and stopping it are the group's, not a member's.
// It lives inside the scene (no extra window) and closes on any choice,
// a click elsewhere or Escape. "Create a group…" does not close it: the
// group chooser takes the place of the entries until a group is made.
Item {
    id: menu
    readonly property PaperColors paper: PaperColors {}

    required property var scene
    property var body: null
    readonly property bool open: !!body
    // "Forget" was clicked once: the next click on it unpairs
    property bool confirmForget: false
    // The group chooser is open in place of the entries
    property bool choosing: false

    readonly property var entries: {
        const b = body;
        if (!b)
            return [];
        const info = b.ancCapable ? scene.ancFor(b.address) : null;
        const member = scene.together.isMember(b.address);
        return Entries.list({
            "device": !!b.device,
            "wired": !!b.wired,
            "phase": b.phase,
            "connected": b.connected,
            "modes": info?.features?.modes,
            "mode": info?.state?.mode ?? "",
            "member": member,
            "groupEntry": scene.together.canGroup(b) ? Choice.labels(scene.together.members(), member).entry : "",
            "paired": !!(b.device && b.paired),
            "confirmForget": confirmForget
        });
    }

    function popup(b, point) {
        confirmForget = false;
        choosing = false;
        body = b;
        // Keep the menu inside the scene
        panel.x = Math.max(8, Math.min(point.x, scene.width - panel.width - 8));
        panel.y = Math.max(8, Math.min(point.y, scene.height - panel.height - 8));
        if (b.ancCapable)
            scene.ancWatch(b.address, true);   // fetch the current mode
        _watching = b.ancCapable ? b.address : "";
        scene.forceActiveFocus();
    }

    // The group chooser on its own, for the group's radar ("Add a device…"): the
    // page "Create a group…" opens, without the entries before it
    function addDevices(b, point) {
        popup(b, point);
        choosing = true;
    }

    property string _watching: ""
    function close() {
        if (_watching)
            scene.ancWatch(_watching, false);
        _watching = "";
        if (choosing) {
            choosing = false;
            scene.forceActiveFocus();   // the chooser had the keyboard
        }
        body = null;
    }

    function choose(id) {
        // Forgetting unpairs: the first click only arms it
        if (id === "forget" && !confirmForget) {
            confirmForget = true;
            return;
        }
        // A group is made on its own page: the menu stays until it is done
        if (id === "group") {
            choosing = true;
            return;
        }
        const b = body;
        close();
        if (!b)
            return;
        if (id === "connect")
            scene.startConnect(b);
        else if (id === "disconnect")
            scene.startDisconnect(b);
        else if (id === "cancel")
            scene.cancelConnect(b);
        else if (id === "leave")
            scene.together.leave(b.address);
        else if (id === "hide")
            scene.hideBody(b);
        else if (id === "forget")
            scene.forget(b);
        else if (id.startsWith("anc:"))
            scene.ancSend(b.address, "mode", id.slice(4));
    }

    anchors.fill: parent
    visible: open

    // Click anywhere else closes it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: menu.close()
    }

    Rectangle {
        id: panel
        visible: !menu.choosing
        width: 168
        height: menu.entries.length * 32 + 10   // known before layout, for placement
        radius: 14
        color: menu.paper.fill(0.95)
        border.width: 1
        border.color: menu.paper.fg(0.08)
        transformOrigin: Item.TopLeft
        scale: menu.open ? 1 : 0.92
        opacity: menu.open ? 1 : 0
        Behavior on scale {
            enabled: menu.scene.motion
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: col
            x: 5
            y: 5
            width: parent.width - 10

            Repeater {
                model: menu.entries

                Rectangle {
                    required property var modelData
                    readonly property bool danger: modelData.danger ?? false
                    width: col.width
                    height: 32
                    radius: 10
                    color: danger && menu.confirmForget ? Theme.withAlpha(Theme.error, 0.16) : itemArea.containsMouse ? menu.paper.fg(0.08) : "transparent"

                    // A hairline before the entries that start a section (MenuEntries.ruled)
                    Rectangle {
                        visible: modelData.rule
                        x: 8
                        width: parent.width - 16
                        height: 1
                        color: menu.paper.fg(0.07)
                    }
                    DankIcon {
                        id: icon
                        x: 9
                        anchors.verticalCenter: parent.verticalCenter
                        name: modelData.icon
                        size: 16
                        color: modelData.checked ? Theme.primary : danger ? Theme.error : menu.paper.fg(0.75)
                    }
                    StyledText {
                        anchors.left: icon.right
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: modelData.checked ? Theme.primary : danger ? Theme.error : menu.paper.ink
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: modelData.checked ? Font.DemiBold : Font.Normal
                    }
                    DankIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.checked ?? false
                        name: "check"
                        size: 14
                        color: Theme.primary
                    }
                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.choose(modelData.id)
                    }
                }
            }
        }
    }

    // The group chooser, built when "Create a group…" is chosen and gone with it
    Loader {
        active: menu.choosing
        sourceComponent: GroupChooser {
            scene: menu.scene
            paper: menu.paper
            address: menu.body?.address ?? ""
            origin: Qt.point(panel.x, panel.y)
            onConfirmed: list => {
                menu.close();
                menu.scene.together.groupFrom(list);
            }
            onRefused: (why, who) => menu.scene.together.refuse(why, who)
        }
    }
}
