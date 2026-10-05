pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets
import "../card"
import "../noise/Anc.js" as Anc
import "../together/Choice.js" as Choice

// Right-click menu of an orbiting device: connect/disconnect, the headset's
// noise-control modes when it has them, "Create a group…" (or "Add to the
// group…") for a device that can play sound, "Leave together" and "Stop
// together" for a device that listens together with others, "Hide" (into the
// black hole) and "Forget" (unpair), which asks for a second click.
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
        const list = [];
        if (b.device)
            list.push(b.phase === "connecting" ? {
                "id": "cancel",
                "icon": "close",
                "label": "Cancel"
            } : b.connected ? {
                "id": "disconnect",
                "icon": "link_off",
                "label": "Disconnect"
            } : {
                "id": "connect",
                "icon": "link",
                "label": "Connect"
            });
        if (b.ancCapable) {
            const info = scene.ancFor(b.address);
            const modes = Anc.ordered(info?.features?.modes);
            for (const m of modes)
                list.push({
                    "id": "anc:" + m,
                    "icon": Anc.ICONS[m],
                    "label": Anc.SHORT[m],
                    "checked": info?.state?.mode === m
                });
        }
        if (scene.together.canGroup(b))
            list.push({
                "id": "group",
                "icon": "group_add",
                "label": Choice.labels(scene.together.members(), scene.together.isMember(b.address)).entry
            });
        if (scene.together.isMember(b.address)) {
            // With only two, leaving is the same as stopping
            if (scene.together.count() > 2)
                list.push({
                    "id": "leave",
                    "icon": "logout",
                    "label": "Leave together"
                });
            list.push({
                "id": "separate",
                "icon": "call_split",
                "label": "Stop together"
            });
        }
        list.push({
            "id": "hide",
            "icon": "visibility_off",
            "label": "Hide"
        });
        if (b.device && b.paired)
            list.push({
                "id": "forget",
                "icon": confirmForget ? "delete_forever" : "delete",
                "label": confirmForget ? "Click to forget" : "Forget",
                "danger": true
            });
        return list;
    }

    // The Listen together entries sit together, under one hairline
    function isTogetherEntry(id) {
        return id === "group" || id === "leave" || id === "separate";
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
        else if (id === "separate")
            scene.together.stop();
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
                    required property int index
                    readonly property bool danger: modelData.danger ?? false
                    width: col.width
                    height: 32
                    radius: 10
                    color: danger && menu.confirmForget ? Theme.withAlpha(Theme.error, 0.16) : itemArea.containsMouse ? menu.paper.fg(0.08) : "transparent"

                    // A hairline before the Listen together entries or "Hide" (once) and before the first mode
                    Rectangle {
                        visible: index > 0 && ((menu.isTogetherEntry(modelData.id) && !menu.isTogetherEntry(menu.entries[index - 1].id)) || (modelData.id === "hide" && !menu.isTogetherEntry(menu.entries[index - 1].id)) || (modelData.id.startsWith("anc:") && !menu.entries[index - 1].id.startsWith("anc:")))
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
